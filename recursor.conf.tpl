{% for key, value in environment('RECURSOR_') %}{{ key|replace('_', '-') }}={{ value }}
{% endfor %}
