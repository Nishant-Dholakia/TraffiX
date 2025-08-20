import os
from fastapi import FastAPI
from pydantic import BaseModel

from helper import extract_text_from_pdf
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_core.prompts import PromptTemplate
from langchain_community.llms import Ollama
from fastapi import Body
# === Initialize FastAPI ===
app = FastAPI(title="Legal Q&A API")

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# === Setup paths ===
text_file_path = "data/vehicle-act.txt"
faiss_path = "vector_store/faiss_index"

# === STEP 1: Load or extract text ===
if not os.path.exists(text_file_path):
    print("Extracting text from PDF...")
    text = extract_text_from_pdf("vehicle-act.pdf")
    os.makedirs("data", exist_ok=True)
    with open(text_file_path, "w", encoding="utf-8") as f:
        f.write(text)
else:
    print("Loading text from file...")
    with open(text_file_path, "r", encoding="utf-8") as f:
        text = f.read()

# === STEP 2: Split text ===
splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
chunks = splitter.create_documents([text])

# === STEP 3: Setup embeddings + vector store ===
os.makedirs("vector_store", exist_ok=True)
embeddings = HuggingFaceEmbeddings(model_name="BAAI/bge-small-en-v1.5")

if os.path.exists(faiss_path):
    print("Loading vector store from disk...")
    vector_store = FAISS.load_local(
        faiss_path, embeddings, allow_dangerous_deserialization=True
    )
else:
    print("Creating new vector store...")
    vector_store = FAISS.from_documents(chunks, embeddings)
    vector_store.save_local(faiss_path)

retriever = vector_store.as_retriever(search_type="similarity", search_kwargs={"k": 5})

# === Prompt template ===
prompt_template = PromptTemplate(
    input_variables=["context", "question"],
    template="""
You are a legal expert. Based on the following context from the Motor Vehicles Act, answer the question.

Context:
{context}

Question:
{question}

Answer:"""
)

llm = Ollama(model="llama3.2")

# === Request body schema ===
class QueryRequest(BaseModel):
    question: str

# === API Endpoint ===
@app.post("/ask")
def ask_question(request: QueryRequest = Body(...)):
    question = request.question

    # retrieve context
    similar_chunks = retriever.invoke(question)
    context = "\n\n".join([doc.page_content for doc in similar_chunks])

    # build prompt
    final_prompt = prompt_template.format(context=context, question=question)

    # query LLM
    response = llm.invoke(final_prompt)

    return {"question": question, "answer": response}


from pyngrok import ngrok

if __name__ == "__main__":
    # Open ngrok tunnel
    public_url = ngrok.connect(8000)
    print("Public URL:", public_url)

    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
