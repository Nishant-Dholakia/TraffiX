from .pdf_text import text
#step-2 text - splits - chunks
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain_core.prompts import PromptTemplate

splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=200)
chunks = splitter.create_documents([text])

# print(f"Total chunks created: {len(chunks)}")

#step-3 chunks - embeddings - vector store
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS
embeddings = HuggingFaceEmbeddings(model_name="BAAI/bge-small-en-v1.5")
vector_store = FAISS.from_documents(chunks, embeddings)
