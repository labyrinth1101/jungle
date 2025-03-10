<script>
	import { asset } from './../../lib/store.js';
  import {
    artworksLimit,
    prompt,
    messageUser,
    tipUser,
    user,
  } from "$lib/store";
  import Fa from "svelte-fa";
  import {
    faEnvelope,
    faLink,
    faMapMarkerAlt,
    faWallet,
  } from "@fortawesome/free-solid-svg-icons";
  import { faTwitter, faInstagram } from "@fortawesome/free-brands-svg-icons";
  import { page } from "$app/stores";
  import { onMount } from "svelte";
  import { err, goto, copy } from "$lib/utils";
  import { fromBase58 } from "bip32";
  import {
    Avatar,
    Card,
    Offers,
    ProgressLinear,
    SendMessage,
    SendTip,
  } from "$comp";
  import { createFollow, deleteFollow } from "$queries/follows";
  import { getUserByUsername } from "$queries/users";
  import Menu from "./_menu.svelte";
  import { query } from "$lib/api";
  import { network } from "$lib/wallet";
  import qrcode from "qrcode";

  export let id;
  export let subject;

  $: pageChange($page);

  const pageChange = ({ params }) => {
    if (params.id) ({ id } = params);
    else ({ id } = subject);
  };

  let refreshUser = async () => {
    try {
      let { users } = await query(getUserByUsername, {
        username: subject.username,
        artworksLimit: $artworksLimit,
      });
      subject = users[0];
    } catch (e) {
      console.log(e);
    }
  };

  let follow = () => {
    if (subject.followed) {
      query(deleteFollow($user, subject)).catch(err);
      subject.followed = false;
      subject.num_followers--;
    } else {
      query(createFollow(subject));
      subject.followed = true;
      subject.num_followers++;
    }
  };

  let qr, showQr;
  let toggleQr = () => {
    showQr = !showQr;
  };

  onMount(async () => {
    let address = subject.address;
    address = `bitcoin:${address}`;
    qr = await qrcode.toDataURL(address);
  });

  let tab = subject.is_artist ? "creations" : "collection";
</script>

<div class="container mx-auto lg:px-16 mt-5 md:mt-20">
  {#if subject}
    <div class="flex justify-between flex-wrap">
      <div class="w-full xl:w-1/3 xl:max-w-xs">
        <div class="w-full flex flex-col">
          <div class="flex items-center">
            <Avatar size="large" user={subject} />
            <div class="ml-12">
              <h3>{subject.full_name}</h3>
              <div class="text-gray-600">@{subject.username}</div>
            </div>
          </div>
          <div class="flex mt-5">
            <div class="mr-8">Followers: {subject.num_followers}</div>
            <div>Following: {subject.num_follows}</div>
          </div>
        </div>
        {#if $user}
          {#if $user.id === subject.id}
            <Menu />
          {:else}
            <div class="grid grid-cols-3 gap-2 mb-10">
              <button
                class="p-2 primary-btn follow mt-8 w-full"
                on:click={follow}
              >
                {subject.followed ? "Unfollow" : "Follow"}</button
              >
              <button
                class="p-2 primary-btn mt-8 w-full"
                on:click={() => {
                  $messageUser = subject;
                  prompt.set(SendMessage);
                }}
              >
                Message</button
              >
              <button
                class="p-2 primary-btn mt-8 w-full"
                on:click={() => {
                  $tipUser = {
                    username: subject.username,
                    address: subject.address,
                  };
                  prompt.set(SendTip);
                }}
              >
                Tip</button
              >
            </div>
          {/if}
        {/if}
        {#if subject.bio}
          <p class="my-4">{subject.bio}</p>
        {/if}
        <div class="social-details mt-4">
          {#if subject.instagram}
            <a href={`https://instagram.com/${subject.instagram}`}>
              <div class="flex">
                <div class="my-auto">
                  <Fa icon={faInstagram} />
                </div>
                <div><span>@{subject.instagram}</span></div>
              </div>
            </a>
          {/if}
          {#if subject.twitter}
            <a href={`https://twitter.com/${subject.twitter}`}>
              <div class="flex">
                <div class="my-auto">
                  <Fa icon={faTwitter} />
                </div>
                <div><span>@{subject.twitter}</span></div>
              </div>
            </a>
          {/if}
          {#if subject.email}
            <a href={`mailto:${subject.email}`}>
              <div class="flex">
                <div class="my-auto">
                  <Fa icon={faEnvelope} />
                </div>
                <div><span>{subject.email}</span></div>
              </div>
            </a>
          {/if}
          {#if subject.website}
            <a href={`https://${subject.website}`}>
              <div class="flex">
                <div class="my-auto">
                  <Fa icon={faLink} />
                </div>
                <div><span>{subject.website}</span></div>
              </div>
            </a>
          {/if}
          {#if subject.location}
            <div class="flex">
              <div class="my-auto">
                <Fa icon={faMapMarkerAlt} />
              </div>
              <div><span>{subject.location}</span></div>
            </div>
          {/if}
          <div class="flex cursor-pointer">
            <div class="my-auto">
              <Fa icon={faWallet} />
            </div>
            <div on:click={toggleQr} class="truncate">
              <span>{subject.address}</span>
            </div>
          </div>
        </div>
        {#if showQr}
          <div
            class="w-full cursor-pointer font-semibold text-xs text-center"
            on:click={() => copy(subject.address)}
          >
            <img src={qr} class="w-64 mx-auto" alt="QR Code" />
            <div>
              {subject.address}
            </div>
          </div>
        {/if}
      </div>

      <div class="w-full xl:w-2/3">
        <div
          class="flex justify-center text-center cursor-pointer tabs flex-wrap mb-14"
        >
          {#if subject.is_artist}
            <div
              class:hover={tab === "creations"}
              on:click={() => (tab = "creations")}
            >
              Creations
            </div>
          {/if}
          <div
            class:hover={tab === "collection"}
            on:click={() => (tab = "collection")}
          >
            Collection
          </div>
          {#if $user && $user.id === id}
            <div
              class:hover={tab === "offers"}
              on:click={() => (tab = "offers")}
            >
              Offers
            </div>
            <div
              class:hover={tab === "favorites"}
              on:click={() => (tab = "favorites")}
            >
              Favorites
            </div>
          {/if}
        </div>
        {#if tab === "creations"}
          <div class="w-full justify-center">
            <div class="w-full max-w-sm mx-auto mb-12">
              {#if $user?.is_artist && $user?.id === subject.id}
                <a href="/a/create" class="primary-btn">Submit a new asset</a>
              {/if}
            </div>
            <div class="w-full flex flex-wrap">
              {#each subject.creations as artwork (artwork.id)}
                <div class="gallery-tab w-full lg:w-1/2 px-5 mb-10">
                  <Card {artwork} />
                </div>
              {:else}
                <div class="mx-auto">No creations yet</div>
              {/each}
              {#if $artworksLimit !== undefined && subject.creations.length}
                <a
                  sveltekit:prefetch
                  class="primary-btn mx-auto mb-12 w-full"
                  href={`/artist/${subject.username}`}>Show all</a
                >
              {/if}
            </div>
          </div>
        {:else if tab === "collection"}
          <div class="w-full flex justify-center">
            <div class="w-full flex flex-wrap">
              {#each subject.holdings as artwork (artwork.id)}
                <div class="gallery-tab w-full lg:w-1/2 px-5 mb-10">
                  <Card {artwork} />
                </div>
              {:else}
                <div class="mx-auto">Nothing collected yet</div>
              {/each}
              {#if $artworksLimit !== undefined && subject.holdings.length}
                <a
                  sveltekit:prefetch
                  class="primary-btn mx-auto mb-12 w-full"
                  href={`/${subject.username}/collection`}>Show all</a
                >
              {/if}
            </div>
          </div>
        {:else if tab === "offers"}
          <Offers offers={subject.offers} activebids={subject.activebids} />
        {:else}
          <div class="w-full flex justify-center">
            <div class="w-full flex flex-wrap">
              {#each subject.favorites as { artwork } (artwork.id)}
                <div class="gallery-tab w-full lg:w-1/2 px-0 md:px-5 mb-10">
                  <Card {artwork} />
                </div>
              {:else}
                <div class="mx-auto">No favorites yet</div>
              {/each}
            </div>
          </div>
        {/if}
      </div>
    </div>
  {:else}
    <ProgressLinear app={true} />
  {/if}
</div>

<style>
  .gallery-tab :global(.card-link img),
  .gallery-tab :global(.card-link video) {
    height: 350px;
  }

  .hover {
    @apply border-b-2;
    border-bottom: 3px solid #43470b;
  }

  .tabs div {
    @apply mb-auto h-10 mx-2 md:mx-4;
    &:hover {
      @apply border-b-2;
      border-bottom: 3px solid #43470b;
    }
  }

  .social-details {
    display: flex;
    flex-direction: column;
  }
  .social-details div.flex {
    @apply mb-2;
  }

  .social-details a:hover,
  .social-details span:hover {
    color: gray;
  }

  .social-details span {
    margin-left: 8px;
    color: #43470b;
  }
</style>
