from mcp.server.fastmcp import FastMCP
import os,sys
sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from RAG.rag import rag_answer

# === Initialize FastMCP server ===
mcp = FastMCP("RAG")

# === Register RAG function ===
@mcp.tool(name="traffic", description="Use this tool to answer questions about the Motor Vehicles Act in India.")
def rag_tool(question: str) -> str:
    return rag_answer(question)

# === Start the server ===
if __name__ == "__main__":
    mcp.run(transport="stdio")