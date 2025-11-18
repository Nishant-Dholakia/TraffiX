import os
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from pydantic import BaseModel
from deep_translator import GoogleTranslator
from typing import Any, Dict
from langchain_core.messages import HumanMessage, AIMessage
# Import your MCPAgent class from the previous implementation
from MCP.mcp_class import MCPAgent  # Assuming you saved the previous class in mcp_agent.py

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan context that initializes the MCP agent safely.
    """
    agent = MCPAgent()
    app.state.agent = None  # default to None in case MCP fails
    print("[Lifespan] MCPAgent instance created")

    try:
        print("[Lifespan] Connecting to MCP servers...")
        connected = await agent.connect_to_servers()
        if connected:
            app.state.agent = agent
            print("[Lifespan] MCPAgent connected successfully")
        else:
            print("[Lifespan] Failed to connect to MCP servers, continuing without agent")
        yield  # Must always yield to avoid FastAPI startup crash
    except Exception as e:
        # Log the error but do not break FastAPI startup
        print(f"[Lifespan] Warning: MCP connection failed: {e}")
        yield  # still yield to satisfy FastAPI
    finally:
        print("[Lifespan] Cleaning up MCPAgent...")
        await agent.cleanup()
        print("[Lifespan] MCPAgent shutdown complete")
# === Initialize FastAPI ===
app = FastAPI(title="Legal Q&A API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# === Request Models ===
class QueryRequest(BaseModel):
    question: str

class TranslateRequest(BaseModel):
    text: str
    target_lang: str

class Message(BaseModel):
    role: str
    content: Any

# === API Routes ===
@app.post("/ask")
async def ask_question(req: QueryRequest):
    print("hey")
    """Process a legal question using MCP agent"""
    try:
        response = await app.state.agent.process_query(req.question)
        
        # Extract just the response text (remove "Bot:" prefixes)
        if isinstance(response, str):
            if response.startswith("Bot: "):
                answer = response[5:]
            elif response.startswith("Bot (tool): "):
                answer = response[12:]
            else:
                answer = response
        else:
            answer = str(response)
            
        return {
            "question": req.question, 
            "answer": answer,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/translate")
async def translate_text(req: TranslateRequest):
    """Translate text to target language"""
    try:
        translated_text = GoogleTranslator(
            source='auto', target=req.target_lang
        ).translate(req.text)
        return {
            "original_text": req.text,
            "translated_text": translated_text,
            "target_language": req.target_lang
        }
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/tools")
async def get_tools():
    """Get the list of available tools from MCP server"""
    try:
        if not hasattr(app.state.agent, 'tools'):
            raise HTTPException(status_code=500, detail="Agent not initialized")
        
        tools = app.state.agent.tools
        return {
            "tools": [
                {
                    "name": tool.name,
                    "description": tool.description,
                    # Include other tool properties as needed
                }
                for tool in tools
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/history")
async def get_conversation_history():
    """Get the current conversation history"""
    try:
        if not hasattr(app.state.agent, 'conversation_history'):
            raise HTTPException(status_code=500, detail="Agent not initialized")
        
        history = []
        for message in app.state.agent.conversation_history:
            history.append({
                "role": "user" if isinstance(message, HumanMessage) else "assistant",
                "content": message.content,
                "type": type(message).__name__
            })
        
        return {"conversation_history": history}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/clear")
async def clear_conversation_history():
    """Clear the conversation history"""
    try:
        if hasattr(app.state.agent, 'conversation_history'):
            app.state.agent.conversation_history.clear()
            return {"message": "Conversation history cleared successfully"}
        else:
            raise HTTPException(status_code=500, detail="Agent not initialized")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        agent_healthy = hasattr(app.state, 'agent') and app.state.agent is not None
        tools_available = agent_healthy and len(app.state.agent.tools) > 0
        
        return {
            "status": "healthy",
            "agent_initialized": agent_healthy,
            "tools_available": tools_available,
            "tools_count": len(app.state.agent.tools) if agent_healthy else 0
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# === Run Uvicorn ===
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="localhost", port=8000, reload=True)