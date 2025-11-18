import asyncio
import os
import traceback
from dotenv import load_dotenv
from langchain_core.messages import HumanMessage, AIMessage
from langchain_groq import ChatGroq
from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.prebuilt import create_react_agent

load_dotenv()

async def mcp_server():
    try:
        # === Initialize MCP Client & Tools ===
        client = MultiServerMCPClient(
            {
                "traffic": {
                    "command": "python",
                    "args": ["tool.py"],
                    "transport": "stdio",
                },
            }
        )
        tools = await client.get_tools()

        # === LLM ===
        model = ChatGroq(
            model="openai/gpt-oss-120b",
            api_key=os.getenv("GROQ_API_KEY")
        )

        # === Agent ===
        agent = create_react_agent(model=model, tools=tools)

        # === Conversation history ===
        conversation_history: list = []

        while True:
            query = input("\nYou: ").strip()

            # Handle special commands
            if query.lower() in {"exit", "quit"}:
                print("👋 Goodbye!")
                break
            elif query.lower() == "clear":
                conversation_history.clear()
                print("🗑️ Conversation history cleared!")
                continue
            elif query.lower() == "history":
                if not conversation_history:
                    print("📭 No conversation history yet.")
                else:
                    print("\n=== Conversation History ===")
                    for i, msg in enumerate(conversation_history, 1):
                        role = "You" if isinstance(msg, HumanMessage) else "Bot"
                        print(f"{i}. {role}: {msg.content}")
                    print("============================")
                continue
            elif not query:
                continue

            try:
                # Enhance prompt to keep context
                new_prompt = (
                    query
                    + "\nAnswer as per the Motor Vehicles Act in India."
                    " If answer is based on previous context, ensure it's relevant."
                )
                conversation_history.append(HumanMessage(content=new_prompt))

                # Run agent
                response = await agent.ainvoke({"messages": conversation_history})
                ai_messages = [m for m in response["messages"] if isinstance(m, AIMessage)]

                if not ai_messages:
                    print("Bot: ⚠️ No valid response from agent.")
                    continue

                ai_response = ai_messages[-1]

                # Check if the traffic tool was used
                tool_used = any(
                    getattr(step, "tool_calls", None) or getattr(step, "tool_name", None)
                    for step in response["messages"]
                )

                # --- Context-aware handling ---
                if tool_used:
                    # Tool-provided answer
                    print("Bot (tool):", ai_response.content)
                else:
                    # LLM-generated answer
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
                        print("Bot: ❌ Sorry, I cannot answer that. It's out of scope.")
                    else:
                        # LLM can answer follow-ups using history
                        print("Bot:", ai_response.content)

                # Save response in history
                conversation_history.append(ai_response)

            except Exception as e:
                print(f"❌ Error: {e}")
                traceback.print_exc()

    except Exception as e:
        print(f"🚨 Initialization error: {e}")
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(mcp_server())
