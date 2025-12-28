#!/usr/bin/env python3
"""
Parse Azure DevOps work item JSON and convert to Markdown.

Usage:
    az boards work-item show --id 72382 --output json | python parse-work-item.py
    python parse-work-item.py < work-item.json
    python parse-work-item.py --id 72382  # Fetches and parses directly

Environment Variables:
    CLAUDE_ADO_BASE_URL - Azure DevOps base URL (e.g., https://dev.azure.com/org/Project)
    CLAUDE_CONTEXT_FILE - Default output file path (optional)
"""

import sys
import json
import re
import argparse
import subprocess
import os
from html import unescape


def html_to_markdown(html: str) -> tuple[str, list]:
    """Convert HTML content to Markdown. Returns (text, images_list)."""
    if not html:
        return "", []

    text = html

    # Handle common HTML entities
    text = unescape(text)

    # Convert line breaks
    text = re.sub(r'<br\s*/?>', '\n', text, flags=re.IGNORECASE)

    # Convert headers
    for i in range(1, 7):
        text = re.sub(rf'<h{i}[^>]*>(.*?)</h{i}>', rf'{"#" * i} \1\n', text, flags=re.IGNORECASE | re.DOTALL)

    # Convert bold
    text = re.sub(r'<(?:strong|b)[^>]*>(.*?)</(?:strong|b)>', r'**\1**', text, flags=re.IGNORECASE | re.DOTALL)

    # Convert italic
    text = re.sub(r'<(?:em|i)[^>]*>(.*?)</(?:em|i)>', r'*\1*', text, flags=re.IGNORECASE | re.DOTALL)

    # Convert unordered lists
    text = re.sub(r'<ul[^>]*>', '\n', text, flags=re.IGNORECASE)
    text = re.sub(r'</ul>', '\n', text, flags=re.IGNORECASE)
    text = re.sub(r'<li[^>]*>(.*?)</li>', r'- \1\n', text, flags=re.IGNORECASE | re.DOTALL)

    # Convert ordered lists
    text = re.sub(r'<ol[^>]*>', '\n', text, flags=re.IGNORECASE)
    text = re.sub(r'</ol>', '\n', text, flags=re.IGNORECASE)

    # Convert links
    text = re.sub(r'<a[^>]*href=["\']([^"\']*)["\'][^>]*>(.*?)</a>', r'[\2](\1)', text, flags=re.IGNORECASE | re.DOTALL)

    # Extract images (preserve URLs)
    images = re.findall(r'<img[^>]*src=["\']([^"\']*)["\'][^>]*>', text, flags=re.IGNORECASE)
    text = re.sub(r'<img[^>]*src=["\']([^"\']*)["\'][^>]*/?>', r'![image](\1)', text, flags=re.IGNORECASE)

    # Convert paragraphs
    text = re.sub(r'<p[^>]*>', '\n', text, flags=re.IGNORECASE)
    text = re.sub(r'</p>', '\n', text, flags=re.IGNORECASE)

    # Convert divs to newlines
    text = re.sub(r'<div[^>]*>', '\n', text, flags=re.IGNORECASE)
    text = re.sub(r'</div>', '', text, flags=re.IGNORECASE)

    # Convert code blocks
    text = re.sub(r'<pre[^>]*>(.*?)</pre>', r'```\n\1\n```', text, flags=re.IGNORECASE | re.DOTALL)
    text = re.sub(r'<code[^>]*>(.*?)</code>', r'`\1`', text, flags=re.IGNORECASE | re.DOTALL)

    # Remove remaining HTML tags
    text = re.sub(r'<[^>]+>', '', text)

    # Clean up whitespace
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'[ \t]+', ' ', text)
    text = text.strip()

    return text, images


def extract_parent_id(relations: list) -> str | None:
    """Extract parent work item ID from relations array."""
    if not relations:
        return None

    for rel in relations:
        if rel.get('rel') == 'System.LinkTypes.Hierarchy-Reverse':
            url = rel.get('url', '')
            # Extract ID from URL like: https://dev.azure.com/org/_apis/wit/workItems/12345
            match = re.search(r'/workItems/(\d+)$', url)
            if match:
                return match.group(1)
    return None


def get_base_url() -> str:
    """Get Azure DevOps base URL from environment or return empty string."""
    return os.environ.get('CLAUDE_ADO_BASE_URL', '')


def parse_work_item(data: dict) -> dict:
    """Parse work item JSON into structured data."""
    fields = data.get('fields', {})

    description, desc_images = html_to_markdown(fields.get('System.Description', ''))
    acceptance, acc_images = html_to_markdown(fields.get('Microsoft.VSTS.Common.AcceptanceCriteria', ''))

    # TODO: save images locally and update paths in description and acceptance criteria
    all_images = list(set(desc_images + acc_images))

    base_url = get_base_url()
    work_item_url = f"{base_url}/_workitems/edit/{data.get('id')}" if base_url else ""

    return {
        'id': data.get('id'),
        'title': fields.get('System.Title', ''),
        'type': fields.get('System.WorkItemType', ''),
        'state': fields.get('System.State', ''),
        'description': description,
        'acceptance_criteria': acceptance,
        'assigned_to': fields.get('System.AssignedTo', {}).get('displayName', 'Unassigned'),
        'area_path': fields.get('System.AreaPath', ''),
        'iteration_path': fields.get('System.IterationPath', ''),
        'parent_id': extract_parent_id(data.get('relations', [])),
        'images': all_images,
        'url': work_item_url
    }


def format_markdown(item: dict, parent: dict = None) -> str:
    """Format parsed work item as Markdown."""
    lines = [
        f"# {item['type']} #{item['id']}: {item['title']}",
        "",
        f"**State:** {item['state']}  ",
        f"**Assigned To:** {item['assigned_to']}  ",
        f"**Area:** {item['area_path']}  ",
        f"**Iteration:** {item['iteration_path']}  ",
    ]

    if item['url']:
        lines.append(f"**Link:** [{item['id']}]({item['url']})")

    lines.append("")

    if parent:
        lines.extend([
            "## Parent Work Item",
            "",
            f"**{parent['type']} #{parent['id']}:** {parent['title']}",
            "",
            parent['description'] if parent['description'] else "*No description*",
            "",
        ])

    lines.extend([
        "## Description",
        "",
        item['description'] if item['description'] else "*No description provided*",
        "",
    ])

    if item['acceptance_criteria']:
        lines.extend([
            "## Acceptance Criteria",
            "",
            item['acceptance_criteria'],
            "",
        ])

    if item['images']:
        lines.extend([
            "## Embedded Images",
            "",
            *[f"- {img}" for img in item['images']],
            "",
        ])

    return '\n'.join(lines)


def fetch_work_item(work_item_id: str) -> dict:
    """Fetch work item using Azure CLI."""
    try:
        # On Windows, use shell=True to find az.cmd in PATH
        cmd = f'az boards work-item show --id {work_item_id} --output json'
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            shell=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error fetching work item: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON response: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description='Parse Azure DevOps work item to Markdown')
    parser.add_argument('--id', type=str, help='Work item ID to fetch directly')
    parser.add_argument('--output', '-o', type=str, help='Output file path (default: stdout, or $CLAUDE_CONTEXT_FILE)')
    parser.add_argument('--with-parent', action='store_true', help='Also fetch and include parent work item')
    args = parser.parse_args()

    # Get work item data
    if args.id:
        data = fetch_work_item(args.id)
    elif not sys.stdin.isatty():
        try:
            data = json.load(sys.stdin)
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON from stdin: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        parser.print_help()
        sys.exit(1)

    # Parse main work item
    item = parse_work_item(data)

    # Optionally fetch parent
    parent = None
    if args.with_parent and item['parent_id']:
        parent_data = fetch_work_item(item['parent_id'])
        parent = parse_work_item(parent_data)

    # Format output
    markdown = format_markdown(item, parent)

    # Determine output path
    output_path = args.output or os.environ.get('CLAUDE_CONTEXT_FILE')

    # Output
    if output_path:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(markdown)
        print(f"Written to {output_path}", file=sys.stderr)
    else:
        print(markdown)


if __name__ == '__main__':
    main()
