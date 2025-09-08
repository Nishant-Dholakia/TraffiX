import os
from fastapi import FastAPI, Body
from pydantic import BaseModel

from helper import extract_text_from_pdf
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
from langchain_core.prompts import PromptTemplate
import dotenv
dotenv.load_dotenv()
from fastapi.middleware.cors import CORSMiddleware
from groq import Groq


# === Initialize FastAPI ===
app = FastAPI(title="Legal Q&A API")

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
from langchain_core.prompts import PromptTemplate

prompt_template = PromptTemplate(
    input_variables=["context", "question"],
    template="""
You are a legal expert specializing in the Motor Vehicles Act. 
Answer the user's question strictly using the information provided in the Act. 

Rules:
1. If the answer is present, provide a clear and concise response.
2. If the answer cannot be found, respond only with: 
   "I am unable to find relevant information in the Motor Vehicles Act to answer this question."
3. Do not add any extra details or assumptions beyond the Act.

Excerpt from the Motor Vehicles Act:
{context}

Question:
{question}

Answer:
"""
)


# === Initialize Groq client ===
client = Groq(api_key=os.getenv("GROQ_API_KEY"))


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

    # query Groq LLM
    completion = client.chat.completions.create(
        model="openai/gpt-oss-120b",  # ✅ model you chose
        messages=[{"role": "user", "content": final_prompt}],
        temperature=1,
        max_completion_tokens=1024,
        top_p=1,
        reasoning_effort="medium",
        stream=False,  # ❌ not streaming here, easier for API response
    )

    # Extract answer
    answer = completion.choices[0].message.content

    return {"question": question, "answer": answer}

class TranslateRequest(BaseModel):
    text: str
    target_lang: str

from deep_translator import GoogleTranslator

class TranslateRequest(BaseModel):
    text: str
    target_lang: str

@app.post("/translate")
def translate_text(req: TranslateRequest):
    try:
        translated_text = GoogleTranslator(
            source='auto', target=req.target_lang
        ).translate(req.text)
        return {"translated_text": translated_text}
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":

    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)
