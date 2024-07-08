<script>
  import Search from './Search.svelte';
</script>

<main>
  <h1>SmartIndex by </h1>
  <h1> Edinfinite.com</h1>
  <Search />
</main>

<style>
  main {
    text-align: center;
    padding: 1em;
    max-width: 240px;
    margin: 0 auto;
  }

  h1 {
    color: #9855ea;
    text-transform: uppercase;
    font-size: 4em;
    font-weight: 100;
  }

  @media (min-width: 640px) {
    main {
      max-width: none;
    }
  }
</style>
