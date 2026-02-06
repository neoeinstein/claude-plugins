# Askama Template Inheritance

## When to Use This Reference

- Setting up base templates with blocks
- Using `{% extends %}` for child templates
- Including partial templates with `{% include %}`
- Understanding block scope and limitations

## Quick Reference

| Directive | Purpose | Scope |
|-----------|---------|-------|
| `{% extends "base.html" %}` | Inherit from parent | Must be first in file |
| `{% block name %}` | Define overridable section | Top level or inside other blocks only |
| `{% include "partial.html" %}` | Insert another template | Shares parent context |
| `{{ super() }}` | Include parent block content | Inside block only |

## The Rule

Template inheritance in Askama works like class inheritance:
- Base template defines structure and blocks
- Child templates override specific blocks
- `super()` calls the parent's version

**Critical constraint:** Blocks can only be defined at the top level or inside other blocks. You cannot define blocks inside `{% if %}` or `{% for %}`.

## Patterns

### Base Template

```html
<!-- templates/base.html -->
<!DOCTYPE html>
<html>
<head>
    <title>{% block title %}Default Title{% endblock %}</title>
    {% block extra_head %}{% endblock %}
</head>
<body>
    <nav>{% block nav %}{% include "nav.html" %}{% endblock %}</nav>
    <main>{% block content %}{% endblock %}</main>
    <footer>{% block footer %}&copy; 2024{% endblock %}</footer>
</body>
</html>
```

### Child Template

```html
<!-- templates/event.html -->
{% extends "base.html" %}

{% block title %}{{ event.name }} - Events{% endblock %}

{% block extra_head %}
<link rel="stylesheet" href="/css/events.css">
{% endblock %}

{% block content %}
<h1>{{ event.name }}</h1>
<p>{{ event.description }}</p>
{% endblock %}
```

### Using super()

```html
{% extends "base.html" %}

{% block footer %}
    {{ super() }}
    <p>Additional footer content</p>
{% endblock %}
```

### Including Partials

```html
{% block content %}
<ul>
    {% for item in items %}
        {% include "item_row.html" %}
    {% endfor %}
</ul>
{% endblock %}
```

Included templates have access to all variables from the parent scope.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Block inside `{% if %}` | Compile error | Move block outside conditional, put conditional inside block |
| Block inside `{% for %}` | Compile error | Move block outside loop, put loop inside block |
| Missing `{% extends %}` | Blocks not rendered | Add extends as first line |
| Wrong extends path | Template not found | Use path relative to templates directory |

### Block Scope Error Example

**Wrong:**
```html
{% if show_sidebar %}
    {% block sidebar %}...{% endblock %}
{% endif %}
```

**Right:**
```html
{% block sidebar %}
    {% if show_sidebar %}...{% endif %}
{% endblock %}
```

## Multiple Inheritance Levels

```html
<!-- base.html -->
{% block content %}{% endblock %}

<!-- layout.html -->
{% extends "base.html" %}
{% block content %}
<div class="container">{% block inner %}{% endblock %}</div>
{% endblock %}

<!-- page.html -->
{% extends "layout.html" %}
{% block inner %}
<p>Page content here</p>
{% endblock %}
```

## Resources

- [Template Inheritance](https://askama.readthedocs.io/en/stable/template_syntax.html#template-inheritance)
- [Include Directive](https://askama.readthedocs.io/en/stable/template_syntax.html#include)
