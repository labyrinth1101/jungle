<script>
  import branding from "$lib/branding";
  import { Avatar, Search } from "$comp";
  import { unreadMessages, user } from "$lib/store";
  import { session } from "$app/stores";

  export let open = false;
  let toggle = () => (open = !open);
</script>

<div class="flex justify-between items-center menu relative">
  <Search suggest={false} />
  <a sveltekit:prefetch href="/market"
    ><button on:click={toggle}>Market</button></a
  >
  <a sveltekit:prefetch href="/activity"
    ><button on:click={toggle}>Activity</button></a
  >
  <a href={branding.urls.external.blog}
    ><button on:click={toggle}>Blog</button></a
  >
  <a href="/help"><button on:click={toggle}>Help</button></a>
  {#if $session.user}
    {#if $session.user.is_admin}
      <a href="/admin"><button on:click={toggle}>Admin</button></a>
    {/if}
    <div class="relative">
      <a href={`/${$user?.username}`}>
        <button on:click={toggle} class="flex">
          <Avatar user={$user} />
        </button>
      </a>
      {#if $unreadMessages.length > 0}
        <div
          class="absolute top-0 right-2 bg-primary rounded-full cursor-default px-2 font-bold text-xs"
        >
          {$unreadMessages.length}
        </div>
      {/if}
    </div>
  {:else}<a href="/login"><button on:click={toggle}>Sign In</button></a>{/if}
</div>

<style>
  .menu button {
    width: auto;
    text-align: left;
    padding: 0 20px;
  }

  .menu :global(.search) {
    border: 1px solid lightgray;
    border-radius: 30px;
    margin-right: 15px;
    width: 250px;
  }

  .menu :global(.search):focus-within {
    border: 1px solid #43470b;
    border-radius: 30px;
  }

  .menu :global(input) {
    width: auto;
    width: 80%;
    border: none;
    background: none;
    padding: 0.5rem 1.2rem;
  }

  .menu :global(.fa-search) {
    font-size: 1.2rem;
  }

  @media only screen and (max-width: 1023px) {
    .menu :global(.search) {
      display: none;
    }
  }

  @media only screen and (max-width: 1023px) {
    .menu {
      flex-direction: column;
      align-items: flex-start;
      margin-top: 64px;
      width: 100%;
    }

    .menu a {
      margin: 25px 0 0 0px;
      width: 100%;
    }
  }
</style>
