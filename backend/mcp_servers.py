"""
MCP server configurations and setup for security analysis tools.
"""

import os
from typing import Dict, Any
from agents.mcp import MCPServerStdio, create_static_tool_filter


def get_semgrep_server_params() -> Dict[str, Any]:
    """Get configuration parameters for the Semgrep MCP server."""
    # Build environment with proxy settings if available
    env = os.environ.copy()
    
    # Ensure proxy variables are passed to uvx subprocess
    for proxy_var in ['http_proxy', 'https_proxy', 'HTTP_PROXY', 'HTTPS_PROXY', 'no_proxy', 'NO_PROXY']:
        if proxy_var in os.environ:
            env[proxy_var] = os.environ[proxy_var]
    
    return {
        "command": "uvx",
        "args": [
            "--python", "3.12",  # Force Python 3.12 to avoid 3.14 protobuf issues
            "--with",
            "mcp==1.12.2",
            "--quiet",
            "semgrep-mcp==0.8.1",  # Last version before deprecation
        ],
        "env": env,
    }


def create_semgrep_server() -> MCPServerStdio:
    """Create and configure the Semgrep MCP server instance."""
    params = get_semgrep_server_params()
    return MCPServerStdio(
        params=params,
        client_session_timeout_seconds=120,
        tool_filter=create_static_tool_filter(allowed_tool_names=["semgrep_scan"]),
    )
