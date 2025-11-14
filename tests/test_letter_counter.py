import pytest
from agent import letter_counter

def test_letter_counter_basic():
    """Test basic functionality of letter_counter"""
    assert letter_counter("hello", "l") == 2
    assert letter_counter("world", "o") == 1
    assert letter_counter("Python", "p") == 1  # Case insensitive
    assert letter_counter("aaaaa", "a") == 5
    assert letter_counter("test", "x") == 0  # Letter not in word

def test_letter_counter_edge_cases():
    """Test edge cases for letter_counter"""
    assert letter_counter("", "a") == 0  # Empty string
    
    # Test empty letter - should raise ValueError
    with pytest.raises(ValueError):
        letter_counter("hello", "")

def test_letter_counter_invalid_inputs():
    """Test invalid inputs for letter_counter"""
    # Test multiple letters - should raise ValueError
    with pytest.raises(ValueError):
        letter_counter("hello", "ll")
    
    assert letter_counter(123, "a") == 0  # Non-string word
    assert letter_counter("hello", 1) == 0  # Non-string letter

def test_letter_counter_case_insensitive():
    """Test that letter_counter is case insensitive"""
    assert letter_counter("HELLO", "l") == 2
    assert letter_counter("Hello", "L") == 2
    assert letter_counter("hello", "L") == 2
    assert letter_counter("HELLO", "l") == 2