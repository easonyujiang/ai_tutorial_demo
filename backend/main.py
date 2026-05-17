from dotenv import load_dotenv
from fastapi import FastAPI
from routers import analysis

load_dotenv()

app = FastAPI()

app.include_router(analysis.router)

@app.get("/")
async def root():
    return {"message": "AI Tutorial Backend is running"}