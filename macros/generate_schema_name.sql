{#- Environment-aware schema names:
      prod -> the configured schema as is:            staging, intermediate, marts
      dev  -> prefixed with the target schema:        dev_staging, dev_intermediate, dev_marts
    so a development run never overwrites the tables that people read. -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
