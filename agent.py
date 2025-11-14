import logging
import os
import warnings
from fastapi import FastAPI
from strands import Agent, tool
from strands_tools import calculator, current_time
import uvicorn

logging.basicConfig(level=logging.INFO)

# Define a custom tool as a Python function using the @tool decorator
@tool
def letter_counter(word: str, letter: str) -> int:
    """
    Count occurrences of a specific letter in a word.

    Args:
        word (str): The input word to search in
        letter (str): The specific letter to count

    Returns:
        int: The number of occurrences of the letter in the word
    """
    if not isinstance(word, str) or not isinstance(letter, str):
        return 0

    if len(letter) != 1:
        raise ValueError("The 'letter' parameter must be a single character")

    return word.lower().count(letter.lower())

def create_agent():
    """Create and return the strands agent."""
    # Create an agent with tools from the community-driven strands-tools package
    # as well as our custom letter_counter tool
    # Configure to use the Amazon Nova micro model on Bedrock
    return Agent(
        name="AWS Agentcore Agent",
        description="A production grade AI agent built for Amazon Bedrock Agent Runtime",
        tools=[calculator, current_time, letter_counter],
        model="amazon.nova-micro-v1:0"
    )

def create_app():
    """Create and configure the FastAPI app."""
    # Import A2AServer here to avoid import issues during testing
    from strands.multiagent.a2a import A2AServer
    
    app = FastAPI()
    
    # Create the agent
    strands_agent = create_agent()
    
    # Use the complete runtime URL from environment variable, fallback to local
    runtime_url = os.environ.get('AGENTCORE_RUNTIME_URL', 'http://127.0.0.1:9000/')
    logging.info(f"Runtime URL: {runtime_url}")
    
    a2a_server = A2AServer(
        agent=strands_agent,
        http_url=runtime_url,
        serve_at_root=True # Serves locally at root (/) regardless of remote URL path complexity
    )
    
    @app.get("/ping")
    def ping():
        return {"status": "healthy"}
    
    app.mount("/", a2a_server.to_fastapi_app())
    
    return app

# Only create the app and run the server when this module is executed directly
app = None
if __name__ == "__main__":
    app = create_app()
    host, port = "0.0.0.0", 9000
    uvicorn.run(app, host=host, port=port)
