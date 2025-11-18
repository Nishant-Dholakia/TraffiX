import os
from langchain_core.prompts import PromptTemplate
from groq import Groq

from RAG.vectorDB import load_or_create_vectordb
import dotenv
dotenv.load_dotenv()
# === Initialize Groq client ===
client = Groq(api_key=os.getenv("GROQ_API_KEY"))

# === Load retriever ===
vector_store = load_or_create_vectordb()
retriever = vector_store.as_retriever(search_type="similarity", search_kwargs={"k": 5})

# === Prompt template ===
prompt_template = PromptTemplate(
    input_variables=["context", "question"],
    template="""
You are a legal expert specializing in the Motor Vehicles Act. 
Answer the user's question strictly using the information provided in the Act. 

Rules:
1. If the answer is present, provide a clear and concise response.
2. Try to give ans in short manner in 2-3 lines if need they u go with more description
3. If the answer cannot be found, respond only with: 
   "I am unable to find relevant information in the Motor Vehicles Act to answer this question."
4. Do not add any extra details or assumptions beyond the Act.

Excerpt from the Motor Vehicles Act:
{context}

Question:
{question}

Answer:
"""
)

# === RAG function ===
def rag_answer(question: str) -> str:
    # retrieve context
    similar_chunks = retriever.invoke(question)
    context = "\n\n".join([doc.page_content for doc in similar_chunks])

    # build prompt
    final_prompt = prompt_template.format(context=context, question=question)

    # query Groq LLM
    completion = client.chat.completions.create(
        model="openai/gpt-oss-120b",
        messages=[{"role": "user", "content": final_prompt}],
        temperature=1,
        max_completion_tokens=1024,
        top_p=1,
        reasoning_effort="medium",
        stream=False,
    )

    return completion.choices[0].message.content


# === Example usage ===
if __name__ == "__main__":
    question = "What are the penalties for driving without a driving license, in india?"
    answer = rag_answer(question)
    print("Q:", question)
    print("A:", answer)
