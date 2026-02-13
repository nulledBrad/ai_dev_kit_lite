# Databricks MCP Lite

48-tool MCP server for Claude Desktop. Gives Claude access to your Databricks workspace for SQL, compute, jobs, pipelines, Unity Catalog, and Apps.

## Prerequisites

- **Windows** with PowerShell
- **git** (`winget install Git.Git`)
- **uv** (recommended) or **Python 3.9+** with pip
  - Install uv: `irm https://astral.sh/uv/install.ps1 | iex`
- **Databricks CLI** auth configured
  - `winget install Databricks.DatabricksCLI`
  - `databricks auth login --profile default`

## Install

```powershell
.\install.ps1
```

Or with a specific Databricks profile:

```powershell
.\install.ps1 -Profile my_workspace
```

The installer will:
1. Clone the Databricks AI Dev Kit repo to `~/.ai-dev-kit/`
2. Create a Python virtual environment
3. Install dependencies
4. Print the JSON config to paste into Claude Desktop

## Configure Claude Desktop

Open `%APPDATA%\Claude\claude_desktop_config.json` and add the block the installer prints inside `"mcpServers"`. Then restart Claude Desktop.

## Tools Included (48)

| Category | Tools |
|---|---|
| **SQL** | `execute_sql`, `execute_sql_multi`, `list_warehouses`, `get_best_warehouse`, `get_table_details` |
| **Compute** | `list_clusters`, `get_best_cluster`, `start_cluster`, `get_cluster_status`, `execute_databricks_command`, `run_python_file_on_databricks` |
| **Jobs** | `create_job`, `get_job`, `list_jobs`, `find_job_by_name`, `update_job`, `delete_job`, `run_job_now`, `get_run`, `get_run_output`, `list_runs`, `cancel_run`, `wait_for_run` |
| **Pipelines** | `create_pipeline`, `create_or_update_pipeline`, `get_pipeline`, `update_pipeline`, `delete_pipeline`, `find_pipeline_by_name`, `start_update`, `get_update`, `stop_pipeline`, `get_pipeline_events` |
| **Unity Catalog** | `manage_uc_objects`, `manage_uc_grants`, `manage_uc_tags`, `manage_uc_connections`, `manage_uc_storage`, `manage_uc_sharing`, `manage_uc_monitors`, `manage_uc_security_policies`, `manage_metric_views` |
| **Apps** | `create_app`, `get_app`, `list_apps`, `deploy_app`, `delete_app`, `get_app_logs` |

## Adding More Tools

Edit `~/.ai-dev-kit/run_server_lite.py` and add imports. Available modules:

```
sql, compute, file, pipelines, jobs, agent_bricks, aibi_dashboards,
serving, unity_catalog, volume_files, genie, manifest, vector_search,
lakebase, lakebase_autoscale, user, apps
```

Then restart Claude Desktop.

## Updating

Re-run the installer with `-Force`:

```powershell
.\install.ps1 -Force
```

This pulls the latest code and reinstalls.
