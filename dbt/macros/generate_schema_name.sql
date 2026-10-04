{#
    By default dbt names schemas "<target schema>_<custom schema>" (e.g. DBT_DEV_STAGING).
    This override uses the custom schema name exactly, so models land in
    CRI_DB.STAGING, CRI_DB.INTERMEDIATE and CRI_DB.MARTS. Easier to find in Snowsight and Tableau.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}
