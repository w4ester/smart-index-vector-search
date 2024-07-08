<script>
  let query = '';
  let results = [];
  let isLoading = false;
  let error = null;

  async function handleSubmit() {
    isLoading = true;
    error = null;
    try {
      const response = await fetch('http://localhost:8000/search', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ query }),
      });
      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`HTTP error! status: ${response.status}, message: ${errorText}`);
      }
      results = await response.json();
      console.log("Raw search results:", results);
      if (results.length === 0) {
        console.log("No results found");
      } else {
        results.forEach((result, index) => {
          console.log(`Result ${index}:`, result);
        });
      }
    } catch (err) {
      console.error("Error during search:", err);
      error = `An error occurred while searching: ${err.message}`;
    } finally {
      isLoading = false;
    }
  }
</script>

<form on:submit|preventDefault={handleSubmit}>
  <input 
    bind:value={query} 
    placeholder="What project do you want to build?"
    disabled={isLoading}
  >
  <button type="submit" disabled={isLoading}>
    {isLoading ? 'Searching...' : 'Search'}
  </button>
</form>

{#if error}
  <p class="error">{error}</p>
{/if}

{#if results.length > 0}
  <h2>Here's what I found:</h2>
  {#each results as result}
    <div class="result">
      <p class="explanation">{result.explanation}</p>
      <p class="content">{result.content}</p>
      <p class="similarity">Relevance: {(result.similarity * 100).toFixed(2)}%</p>
    </div>
  {/each}
{:else}
  <p>No relevant results found.</p>
{/if}

<style>
  form {
    display: flex;
    margin-bottom: 20px;
  }
  input {
    flex-grow: 1;
    padding: 10px;
    font-size: 16px;
    border: 1px solid #ccc;
    border-radius: 4px 0 0 4px;
  }
  button {
    padding: 10px 20px;
    font-size: 16px;
    background-color: #4CAF50;
    color: white;
    border: none;
    border-radius: 0 4px 4px 0;
    cursor: pointer;
  }
  button:disabled {
    background-color: #cccccc;
    cursor: not-allowed;
  }
  .error {
    color: red;
    font-weight: bold;
  }
  .result {
    background-color: white;
    padding: 15px;
    margin-bottom: 15px;
    border-radius: 5px;
    box-shadow: 0 2px 5px rgba(0,0,0,0.1);
  }
  .explanation {
    font-weight: bold;
  }
  .content {
    margin-top: 10px;
  }
  .similarity {
    font-style: italic;
    color: #666;
  }
</style>