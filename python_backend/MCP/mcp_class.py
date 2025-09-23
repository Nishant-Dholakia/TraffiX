# mcp_agent.py
import os
import json
import traceback
from typing import Optional
from contextlib import AsyncExitStack
from datetime import datetime

from langchain_core.messages import HumanMessage, AIMessage
from langchain_groq import ChatGroq
from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.prebuilt import create_react_agent

# from utils.logger import logger

class MCPAgent:
    def __init__(self):
        self.client: Optional[MultiServerMCPClient] = None
        self.agent = None
        self.model = None
        self.tools = []
        self.conversation_history = []
        # self.logger = logger
        self.exit_stack = AsyncExitStack()

    async def connect_to_servers(self):
        base_dir = os.path.dirname(os.path.abspath(__file__))  
        tool_path = os.path.join(base_dir, "tool.py")
        print(f"Tool path: {tool_path}")
        try:
            self.client = MultiServerMCPClient(
                {
                    "traffic": {
                        "command": "python",
                        "args": [tool_path],
                        "transport": "stdio",
                    },
                }
            )
            
            self.tools = await self.client.get_tools()
            
            self.model = ChatGroq(
                model="openai/gpt-oss-120b",
                api_key=os.getenv("GROQ_API_KEY")
            )
            
            self.agent = create_react_agent(model=self.model, tools=self.tools)
            
            print("✅ MCP Agent ready!")
            return True

        except Exception as e:
            print(f"Error connecting to MCP servers: {e}")
            # traceback.print_exc()
            raise

    async def process_query(self, query: str):
        try:
            if query.lower() in {"exit", "quit"}:
                return "exit"
            elif query.lower() == "clear":
                self.conversation_history.clear()
                return "clear"
            elif not query.strip():
                return "empty"
            
            new_prompt = (
                query.strip()
                + "\nAnswer as per the Motor Vehicles Act in India."
                " If answer is based on previous context, ensure it's relevant."
                + " otherwise refuse it" + " provide answer in concise manner."
            )
            
            self.conversation_history.append(HumanMessage(content=new_prompt))

            response = await self.agent.ainvoke({"messages": self.conversation_history})
            ai_messages = [m for m in response["messages"] if isinstance(m, AIMessage)]

            if not ai_messages:
                result = "⚠️ No valid response from agent."
                self.conversation_history.append(AIMessage(content=result))
                return result

            ai_response = ai_messages[-1]

            tool_used = any(
                getattr(step, "tool_calls", None) or getattr(step, "tool_name", None)
                for step in response["messages"]
            )

            if tool_used:
                result = f"Bot (tool): {ai_response.content}"
            else:
                lower_content = ai_response.content.lower()
                out_of_context = any(
                    phrase in lower_content
                    for phrase in [
                        "i am unable",
                        "cannot find",
                        "not available",
                        "don't know",
                    ]
                )
                if out_of_context:
                    result = "❌ Sorry, I cannot answer that. It's out of scope."
                else:
                    result = f"Bot: {ai_response.content}"

            self.conversation_history.append(AIMessage(content=ai_response.content))
            return result

        except Exception as e:
            error_msg = f"Error processing query: {e}"
            print(error_msg)
            traceback.print_exc()
            return error_msg

    async def cleanup(self):
        try:
            if hasattr(self, 'exit_stack'):
                await self.exit_stack.aclose()
            print("MCP Agent shutdown complete")
        except Exception as e:
            print(f"Error during cleanup: {e}")
            traceback.print_exc()
            raise