#
# Copyright 2025 Amazon.com, Inc. and its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#   http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.
#

import asyncio
import json
import logging
import os
from fastmcp import FastMCP
from fastmcp.tools.tool import ToolResult

# Configure logging
logger = logging.getLogger(__name__)

# Create the MCP server
mcp_server = FastMCP(name="AIToolsServer")

# Function to extract MCP tool specs in Bedrock format
async def get_bedrock_tool_specs():
    """Convert MCP tool definitions to Bedrock tool specifications"""
    bedrock_specs = []
    
    tools_dict = await mcp_server.get_tools()
    
    for tool_name, tool in tools_dict.items():
        bedrock_tool = {
            "toolSpec": {
                "name": tool.name,
                "description": tool.description,
                "inputSchema": {
                    "json": json.dumps(tool.parameters)
                }
            }
        }
        bedrock_specs.append(bedrock_tool)
    
    return bedrock_specs

# Function to handle Bedrock tool calls through MCP
# 'tool_content_from_bedrock_event' will be the raw 'toolUse' dictionary from Bedrock.
async def handle_bedrock_tool_call(tool_name: str, tool_content_from_bedrock_event: dict):
    """
    Process a Bedrock tool call using the MCP server.
    This function extracts arguments from the raw Bedrock 'toolUse' event format
    and passes them correctly to the FastMCP tool.
    """
    try:
        # Step 1: Extract the JSON string containing the tool arguments.
        # Nova Sonic (Bedrock models) puts the arguments as a JSON string under the 'content' key.
        tool_arguments_json_str = tool_content_from_bedrock_event.get("content") 

        if not tool_arguments_json_str:
            logger.error(f"Tool '{tool_name}' called by Bedrock event without 'content' key or empty 'content': {tool_content_from_bedrock_event}")
            return {"status": "error", "error": f"Tool '{tool_name}' called without expected arguments in 'content'."}

        # Step 2: Parse the JSON string into a Python dictionary.
        try:
            # This 'parsed_tool_arguments' dictionary contains keys like 'customer_name', 'company_name', etc.
            parsed_tool_arguments = json.loads(tool_arguments_json_str)
        except json.JSONDecodeError:
            logger.error(f"Failed to parse JSON arguments for tool '{tool_name}': {tool_arguments_json_str}", exc_info=True)
            return {"status": "error", "error": f"Invalid JSON arguments for tool '{tool_name}'."}

        logger.info(f"Executing tool {tool_name} with parsed arguments: {parsed_tool_arguments}")
        
        tools_dict = await mcp_server.get_tools()
        tool = tools_dict.get(tool_name.lower()) or next((tool for name, tool in tools_dict.items() if name.lower() == tool_name.lower()), None)
        
        if not tool:
            logger.warning(f"Tool not found: {tool_name}")
            return {"status": "error", "error": f"Tool '{tool_name}' not found"}
        
        # Step 3: Execute the FastMCP tool.
        # For fastmcp's tool.run(), it expects a single dictionary containing all arguments.
        # It handles the unpacking to keyword arguments for the underlying function.
        # --- THE FIX: Pass `parsed_tool_arguments` as a single positional argument ---
        raw_mcp_output = await tool.run(parsed_tool_arguments)
        # --- END OF FIX ---

        processed_result = {} # Initialize as an empty dictionary to ensure a dict is always returned

        logger.info(f"Raw MCP output (type: {type(raw_mcp_output)}): {raw_mcp_output}")

        if isinstance(raw_mcp_output, ToolResult):
            # The actual data should be in its 'content' attribute.
            if hasattr(raw_mcp_output, 'content'):
                content_payload = raw_mcp_output.content
                
                if isinstance(content_payload, dict):
                    processed_result = content_payload
                elif isinstance(content_payload, str):
                    try:
                        processed_result = json.loads(content_payload)
                    except json.JSONDecodeError:
                        processed_result = {"response": content_payload}
                elif isinstance(content_payload, list):
                    if len(content_payload) > 0 and hasattr(content_payload[0], 'text'):
                        content_str = content_payload[0].text
                        try:
                            processed_result = json.loads(content_str)
                        except json.JSONDecodeError:
                            processed_result = {"response": content_str}
                    else:
                        logger.warning(f"List content in ToolResult.content is empty or elements lack 'text' attribute: {content_payload}. Returning string representation.")
                        processed_result = {"response": str(content_payload)}
                elif hasattr(content_payload, 'text'):
                    try:
                        processed_result = json.loads(content_payload.text)
                    except json.JSONDecodeError:
                        processed_result = {"response": content_payload.text}
                else:
                    logger.warning(f"Unexpected content type within ToolResult.content: {type(content_payload)}. Returning string representation.")
                    processed_result = {"response": str(content_payload)}
            else:
                logger.warning("ToolResult object missing 'content' attribute. Returning string representation.")
                processed_result = {"response": str(raw_mcp_output)}

        elif isinstance(raw_mcp_output, dict):
            processed_result = raw_mcp_output
        elif isinstance(raw_mcp_output, list) and len(raw_mcp_output) > 0:
            if hasattr(raw_mcp_output[0], 'text'):
                content_str = raw_mcp_output[0].text
                try:
                    processed_result = json.loads(content_str)
                except json.JSONDecodeError:
                    processed_result = {"response": content_str}
            elif isinstance(raw_mcp_output[0], dict):
                processed_result = raw_mcp_output[0]
            else:
                processed_result = {"data": [str(item) for item in raw_mcp_output]}
        else:
            logger.warning(f"Tool returned unexpected raw type: {type(raw_mcp_output)}. Wrapping in 'response'.")
            processed_result = {"response": str(raw_mcp_output)}

        logger.info(f"Processed result (sent to Bedrock): {processed_result}")
        
        return processed_result
    except Exception as e:
        logger.error(f"Error handling tool call: {str(e)}", exc_info=True)
        return {"status": "error", "error": f"Tool execution failed: {type(e).__name__}: {str(e)}"}

# Function to start the MCP server
async def start_mcp_server(host="127.0.0.1", port=8000):
    """Start the MCP server"""
    logger.info(f"Starting MCP server on {host}:{port}")
    def run_server():
        mcp_server.run(transport="sse", host=host, port=port)
    
    import threading
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    await asyncio.sleep(0.05)