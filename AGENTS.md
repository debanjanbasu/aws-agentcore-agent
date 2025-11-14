# Agent Development Guidelines

This document outlines the best practices and guidelines for developing agents using the `strands` SDK within this project. Adhering to these guidelines ensures consistency, maintainability, and optimal performance of our agents on the Amazon Bedrock Agentcore Runtime.

## 1. Tool Definition and Usage

*   **Python Version and Base Image Compatibility**: Use compatible Python versions and base images that support all required dependencies. The current Dockerfile uses Debian-based images (`python3.14-trixie-slim` for builder and `python:3.14-slim` for runner) to ensure compatibility with packages that require compilation, such as `asyncpg`. While using the absolute latest images is desirable for security updates, stability and compatibility take precedence. Refer to the official Python images on Docker Hub for available tags: [https://hub.docker.com/_/python](https://hub.docker.com/_/python). Update your `Dockerfile` and local development environment accordingly.
*   **Clarity and Specificity**: Each tool should have a clear, concise, and specific description. This description is crucial for the LLM to understand when and how to use the tool effectively.
*   **Type Hinting**: Always use Python type hints for tool function arguments and return values. This helps `strands` generate accurate tool schemas and improves code readability.
*   **Docstrings**: Provide comprehensive docstrings for each tool function, explaining its purpose, arguments, and what it returns.
*   **Error Handling**: Tools should gracefully handle expected errors and return meaningful error messages or appropriate default values. Avoid unhandled exceptions that could crash the agent.
*   **Idempotency**: Design tools to be idempotent where possible, meaning that performing the same operation multiple times has the same effect as performing it once.
*   **Developer Experience**: Use colored output with ANSI escape codes for better developer experience. **Note:** When using `echo` commands with ANSI escape codes *inside a `bash -c '...'` block*, explicitly use `echo -e` (e.g., `echo -e "\033[1;32mSuccess!\033[0m"`) to ensure proper interpretation of escape sequences. For top-level `echo` commands, `echo` is usually sufficient.

## 2. Agent Configuration

*   **Model Selection**: Choose the appropriate Bedrock model for your agent's task, considering factors like cost, performance, and capabilities.
*   **Tool Orchestration**: Carefully consider the order and conditions under which tools are invoked. Optimize for minimal tool calls to reduce latency and cost.

## 3. Testing

*   **Unit Tests for Tools**: Write unit tests for each individual tool to ensure its logic is correct and it handles various inputs and edge cases as expected.
*   **Integration Tests for Agent**: Develop integration tests that simulate user interactions with the agent, verifying that the agent correctly orchestrates tools and generates appropriate responses.
*   **Test Organization**: Organize tests in a separate `tests/` directory with filenames following the pattern `test_*.py`. Use pytest as the testing framework.
*   **Test Dependencies**: Include test dependencies in the `[project.optional-dependencies]` section of `pyproject.toml` under the `test` extra.
*   **Running Tests**: Use `make python-test` or `uv run pytest tests/` to run all tests. For continuous integration, ensure tests can be run in isolation without requiring external services.

## 4. Logging and Observability

*   **Structured Logging**: Implement structured logging within your agent and tools to make it easier to analyze logs in CloudWatch.
*   **Meaningful Log Messages**: Log messages should provide sufficient context to understand the agent's decision-making process and tool invocations.
*   **Sensitive Data**: Be mindful of logging sensitive information. Avoid logging PII or confidential data.

## 5. Performance Optimization

*   **Minimize Latency**: Optimize tool implementations to minimize execution time.
*   **Resource Usage**: Be aware of the computational resources (CPU, memory) consumed by your tools and agent logic.

## 6. Security

*   **Least Privilege**: Ensure that the IAM role associated with the Agentcore Runtime has only the necessary permissions to execute its tasks and invoke required AWS services.
*   **Input Validation**: Validate all inputs to your tools to prevent injection attacks or unexpected behavior.

## Example Tool Structure

```python
from strands import tool

@tool
def example_tool(param1: str, param2: int) -> str:
    """
    A brief description of what this tool does.

    Args:
        param1 (str): Description of param1.
        param2 (int): Description of param2.

    Returns:
        str: Description of the return value.
    """
    # Tool implementation logic
    if param2 < 0:
        raise ValueError("param2 cannot be negative")
    return f"Processed {param1} with value {param2}"

```
