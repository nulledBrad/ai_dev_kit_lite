#!/usr/bin/env python
"""Databricks MCP Server - Lite edition.

Loads only: sql, compute, jobs, pipelines, unity_catalog, apps (48 tools)
To add more modules, add them to the imports below.
Available modules: sql, compute, file, pipelines, jobs, agent_bricks,
    aibi_dashboards, serving, unity_catalog, volume_files, genie,
    manifest, vector_search, lakebase, lakebase_autoscale, user, apps
"""

import sys
import types

from fastmcp import FastMCP
from databricks_mcp_server.middleware import TimeoutHandlingMiddleware

# Create server with middleware
mcp = FastMCP("Databricks MCP Server")
mcp.add_middleware(TimeoutHandlingMiddleware())

# Redirect tool registrations to our mcp instance
_fake = types.ModuleType("databricks_mcp_server.server")
_fake.mcp = mcp
sys.modules["databricks_mcp_server.server"] = _fake

# Import only the tool modules we want
from databricks_mcp_server.tools import (  # noqa: F401, E402
    sql,
    compute,
    jobs,
    pipelines,
    unity_catalog,
    apps,
)

if __name__ == "__main__":
    mcp.run("stdio")
