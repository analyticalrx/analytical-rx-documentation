#!/usr/bin/env ruby
# Generate a full-column ERD from a live PostgreSQL database using psql + Graphviz.

require "cgi"
require "json"
require "open3"
require "shellwords"

DATABASE = ENV.fetch("PGDATABASE", "analytical_rx_design")
OUTPUT_DOT = ENV.fetch("OUTPUT_DOT", "diagrams/canonical-event-postgres-erd.dot")
OUTPUT_SVG = ENV.fetch("OUTPUT_SVG", "diagrams/canonical-event-postgres-erd.svg")
OUTPUT_PNG = ENV.fetch("OUTPUT_PNG", "diagrams/canonical-event-postgres-erd.png")
TARGET_SCHEMA = ENV.fetch("TENANT_SCHEMA", "tenant_template")

def psql_json(sql)
  cmd = ["psql", "-d", DATABASE, "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-c", sql]
  output, status = Open3.capture2e(*cmd)
  unless status.success?
    warn output
    exit status.exitstatus || 1
  end
  JSON.parse(output.strip)
end

def run!(*cmd)
  output, status = Open3.capture2e(*cmd)
  unless status.success?
    warn output
    exit status.exitstatus || 1
  end
end

def html(value)
  CGI.escapeHTML(value.to_s)
end

def quote(value)
  value.to_s.dump
end

def sql_literal(value)
  "'#{value.to_s.gsub("'", "''")}'"
end

columns = psql_json(<<~SQL)
  select coalesce(json_agg(row_to_json(column_rows)), '[]'::json)
  from (
    select
      n.nspname as schema_name,
      c.relname as table_name,
      a.attname as column_name,
      pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type,
      a.attnotnull as not_null,
      a.attnum as ordinal_position,
      exists (
        select 1
        from pg_constraint pk
        where pk.conrelid = c.oid
          and pk.contype = 'p'
          and a.attnum = any(pk.conkey)
      ) as is_primary_key,
      exists (
        select 1
        from pg_constraint fk
        where fk.conrelid = c.oid
          and fk.contype = 'f'
          and a.attnum = any(fk.conkey)
      ) as is_foreign_key
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid
    where c.relkind = 'r'
      and n.nspname = #{sql_literal(TARGET_SCHEMA)}
      and a.attnum > 0
      and not a.attisdropped
    order by n.nspname, c.relname, a.attnum
  ) column_rows;
SQL

foreign_keys = psql_json(<<~SQL)
  select coalesce(json_agg(row_to_json(fk_rows)), '[]'::json)
  from (
    select
      con.conname as constraint_name,
      src_ns.nspname as source_schema,
      src.relname as source_table,
      src_att.attname as source_column,
      dst_ns.nspname as target_schema,
      dst.relname as target_table,
      dst_att.attname as target_column
    from pg_constraint con
    join pg_class src on src.oid = con.conrelid
    join pg_namespace src_ns on src_ns.oid = src.relnamespace
    join pg_class dst on dst.oid = con.confrelid
    join pg_namespace dst_ns on dst_ns.oid = dst.relnamespace
    join unnest(con.conkey) with ordinality as source_key(attnum, ord) on true
    join unnest(con.confkey) with ordinality as target_key(attnum, ord) on target_key.ord = source_key.ord
    join pg_attribute src_att on src_att.attrelid = src.oid and src_att.attnum = source_key.attnum
    join pg_attribute dst_att on dst_att.attrelid = dst.oid and dst_att.attnum = target_key.attnum
    where con.contype = 'f'
      and src_ns.nspname = #{sql_literal(TARGET_SCHEMA)}
    order by src_ns.nspname, src.relname, con.conname, source_key.ord
  ) fk_rows;
SQL

tables = columns.group_by { |column| [column.fetch("schema_name"), column.fetch("table_name")] }

schema_colors = {
  TARGET_SCHEMA => { header: "#dbeafe", border: "#2563eb" }
}

dot = +"digraph canonical_event_erd {\n"
dot << "  graph [rankdir=LR, splines=ortho, nodesep=0.65, ranksep=1.15, bgcolor=\"white\", pad=0.25];\n"
dot << "  node [shape=plain, fontname=\"Helvetica\"];\n"
dot << "  edge [fontname=\"Helvetica\", fontsize=9, color=\"#475569\", arrowsize=0.7];\n\n"

tables.each do |(schema_name, table_name), table_columns|
  colors = schema_colors.fetch(schema_name, { header: "#dbeafe", border: "#2563eb" })
  node_id = "#{schema_name}.#{table_name}"
  dot << "  #{quote(node_id)} [label=<\n"
  dot << "    <TABLE BORDER=\"1\" CELLBORDER=\"1\" CELLSPACING=\"0\" CELLPADDING=\"6\" COLOR=\"#{colors[:border]}\">\n"
  dot << "      <TR><TD BGCOLOR=\"#{colors[:header]}\" COLSPAN=\"3\"><B>#{html(schema_name)}.#{html(table_name)}</B></TD></TR>\n"
  dot << "      <TR><TD BGCOLOR=\"#f8fafc\"><B>Key</B></TD><TD BGCOLOR=\"#f8fafc\"><B>Column</B></TD><TD BGCOLOR=\"#f8fafc\"><B>Type</B></TD></TR>\n"

  table_columns.each do |column|
    key_parts = []
    key_parts << "PK" if column.fetch("is_primary_key")
    key_parts << "FK" if column.fetch("is_foreign_key")
    key_parts << "NN" if column.fetch("not_null")
    dot << "      <TR>\n"
    dot << "        <TD>#{html(key_parts.join(' '))}</TD>\n"
    dot << "        <TD PORT=\"#{html(column.fetch('column_name'))}\" ALIGN=\"LEFT\">#{html(column.fetch('column_name'))}</TD>\n"
    dot << "        <TD ALIGN=\"LEFT\">#{html(column.fetch('data_type'))}</TD>\n"
    dot << "      </TR>\n"
  end

  dot << "    </TABLE>\n"
  dot << "  >];\n\n"
end

foreign_keys.each do |fk|
  source_id = "#{fk.fetch('source_schema')}.#{fk.fetch('source_table')}"
  target_id = "#{fk.fetch('target_schema')}.#{fk.fetch('target_table')}"
  source_column = fk.fetch("source_column")
  target_column = fk.fetch("target_column")
  dot << "  #{quote(source_id)}:#{source_column}:e -> #{quote(target_id)}:#{target_column}:w [label=#{quote(source_column)}, tooltip=#{quote(fk.fetch('constraint_name'))}];\n"
end

dot << "}\n"

File.write(OUTPUT_DOT, dot)
run!("dot", "-Tsvg", OUTPUT_DOT, "-o", OUTPUT_SVG)
run!("dot", "-Tpng", OUTPUT_DOT, "-o", OUTPUT_PNG)

puts "Wrote #{OUTPUT_DOT}"
puts "Wrote #{OUTPUT_SVG}"
puts "Wrote #{OUTPUT_PNG}"
