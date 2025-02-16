<script context="module">
  import { newapi as api, post } from "$lib/api";
  import { browser } from "$app/env";
  import branding from "$lib/branding";
  import { host, satsFormatted, updateBitcoinUnit } from "$lib/utils";
  import Comments from "./_comments.svelte";
  import { bitcoinUnitLocal, fiat } from "$lib/store";

  export async function load({ fetch, params: { slug } }) {
    const props = await fetch(`/artworks/${slug}.json`).then((r) => r.json());

    let { artwork } = props;

    if (!artwork)
      return {
        status: 404,
      };

    if (!browser) {
      try {
        await post("/artworks/viewed", { id: artwork.id }, fetch).res();
        artwork.views++;
      } catch (e) {
        console.log(e);
      }
    }

    props.views = artwork.views;

    let metadata = { ...branding.meta };
    metadata.title = metadata.title + " - " + artwork.title;
    metadata.keywords =
      metadata.keywords + " " + artwork.tags.map((t) => t.tag).join(" ");
    metadata.description = artwork.description.replace(/(?:\r\n|\r|\n)/g, " ");

    let type = "image";
    metadata[type] = `${host}/api/public/${artwork.filename}.png`;
    if (artwork.filetype.includes("video")) type = "video";

    metadata[type] = `${host}/api/public/${artwork.filename}.${
      artwork.filetype.split("/")[1]
    }`;

    props.metadata = metadata;

    return {
      props,
    };
  }
</script>

<script>
  import { page, session } from "$app/stores";
  import { user, token, fiatRates } from "$lib/store";
  import Fa from "svelte-fa";
  import {
    faChevronDown,
    faChevronUp,
    faTimes,
  } from "@fortawesome/free-solid-svg-icons";
  import { getArtworkBySlug, deleteArtwork } from "$queries/artworks";
  import { faHeart, faImage } from "@fortawesome/free-regular-svg-icons";
  import { compareAsc, format, parseISO } from "date-fns";
  import {
    Activity,
    Avatar,
    Card,
    Head,
    ProgressLinear,
    RoyaltyInfo,
    Fiat,
  } from "$comp";
  import Sidebar from "./_sidebar.svelte";
  import { tick, onDestroy, onMount } from "svelte";
  import { art, meta, prompt, password, psbt, commentsLimit } from "$lib/store";
  import countdown from "$lib/countdown";
  import {
    confirm,
    goto,
    err,
    explorer,
    info,
    linkify,
    units,
    underway,
  } from "$lib/utils";
  import { requirePassword } from "$lib/auth";
  import {
    createOffer,
    executeSwap,
    requestSignature,
    sign,
    broadcast,
    releaseToSelf,
    ACCEPTED,
  } from "$lib/wallet";
  import { Psbt } from "liquidjs-lib";
  import { query } from "$lib/api";

  export let artwork, others, metadata, views;

  let release = async () => {
    await requirePassword();
    $psbt = await releaseToSelf(artwork);
    $psbt = await sign();
    $psbt = await requestSignature($psbt);
    await broadcast($psbt);
  };

  $: disabled =
    loading ||
    !artwork.held ||
    (artwork.owner_id === $session?.user?.id && underway(artwork)) ||
    artwork.transactions.some(
      (t) => ["purchase", "creation", "cancel"].includes(t.type) && !t.confirmed
    );

  let start_counter,
    end_counter,
    now,
    auctionTimeout,
    refreshTimeout,
    list_price,
    amount;

  let transaction = {};
  let [sats, val, ticker] = units(artwork.asking_asset);

  let refreshInterval = 5000;
  let refreshArtwork = async () => {
    if (!artwork) return;
    clearTimeout(refreshTimeout);

    try {
      await post("/artworks/held", { id: artwork.id }, fetch).res();
    } catch (e) {
      console.log(e);
    }

    try {
      let { artworks } = await query(getArtworkBySlug, {
        slug: artwork.slug,
        limit: $commentsLimit,
      });
      artwork = artworks[0];
      artwork.views = views;
    } catch (e) {
      console.log(e);
    }

    refreshTimeout = setTimeout(refreshArtwork, refreshInterval);
  };

  let cleanup = () => {
    clearTimeout(auctionTimeout);
    clearTimeout(refreshTimeout);
  };
  onDestroy(cleanup);

  $: browser && init($page.url);
  let init = () => {
    $art = undefined;

    cleanup();

    refreshArtwork();
    update();
  };

  let count = () => {
    clearTimeout(auctionTimeout);
    now = new Date();
    if (!artwork) return;
    start_counter = countdown(parseISO(artwork.auction_start)) || "";
    end_counter = countdown(parseISO(artwork.auction_end)) || "";
    auctionTimeout = setTimeout(count, 1000);
  };

  let update = () => {
    if (!artwork) return;
    $art = artwork;

    count();

    list_price = artwork.list_price;
    list_price = val(artwork.list_price);
  };

  let makeOffer = async (e) => {
    try {
      if (e) e.preventDefault();
      offering = true;
      if (ticker === "L-BTC" && $bitcoinUnitLocal === "sats") {
        transaction.amount = sats(amount / 100000000);
      } else {
        transaction.amount = sats(amount);
      }

      transaction.asset = artwork.asset;
      transaction.type = "bid";

      await requirePassword();

      $psbt = await createOffer(artwork, transaction.amount);
      $psbt = await sign();

      transaction.psbt = $psbt.toBase64();
      transaction.hash = $psbt.data.globalMap.unsignedTx.tx.getId();

      await save();
      await refreshArtwork();

      await api().url("/offer-notifications").post({
        artworkId: artwork.id,
        transactionHash: transaction.hash,
      });

      offering = false;
    } catch (e) {
      console.log(e);
      err(e);
      offering = false;
    }
  };

  let save = async (e) => {
    transaction.artwork_id = artwork.id;
    transaction.asset = artwork.asking_asset;

    let { data, errors } = await api()
      .url("/transaction")
      .post({ transaction })
      .json();

    if (errors) throw new Error(errors[0].message);

    if (transaction.type === "purchase") info("Sold! Congratulations!");
    if (transaction.type === "bid") info("Bid placed!");
    bidding = false;
  };

  let bidding, amountInput, offering;
  let startBidding = async () => {
    bidding = true;
    await tick();
    amountInput.focus();
  };

  let loading;
  let buyNow = async () => {
    try {
      await requirePassword();
      loading = true;

      transaction.amount = -artwork.list_price;
      transaction.asset = artwork.asset;
      transaction.type = "purchase";

      $psbt = await executeSwap(artwork);
      $psbt = await sign();

      if (artwork.has_royalty || artwork.auction_end) {
        $psbt = await requestSignature($psbt);
      }

      await broadcast($psbt);

      let tx = $psbt.extractTransaction();
      transaction.hash = tx.getId();
      transaction.psbt = $psbt.toBase64();

      await save();
      await refreshArtwork();

      await api().url("/mail-purchase-successful").post({
        userId: $user.id,
        artworkId: artwork.id,
      });

      await api().url("/mail-artwork-sold").post({
        userId: artwork.owner.id,
        artworkId: artwork.id,
      });
    } catch (e) {
      err(e);
    }

    loading = false;
  };

  let handleDelete = async () => {
    try {
      if ((await confirm()) === ACCEPTED) {
        await query(deleteArtwork, { id: artwork.id });
        info("Artwork deleted");
        goto("/market");
      }
    } catch (e) {
      err(e);
    }
  };

  $: handleUnitChange($bitcoinUnitLocal);

  let handleUnitChange = () => {
    if (!amount) return;
    amount =
      ticker === "L-BTC" && $bitcoinUnitLocal === "sats"
        ? sats(amount)
        : val(amount);
  };

  let showPopup = false;
  let showActivity = false;

  $: bidFiatAmount = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: $user ? $user.fiat : $fiat,
    signDisplay: "never",
  }).format(
    (artwork.bid && artwork.bid.amount) *
      ($fiatRates[$user ? $user.fiat : $fiat] / 100000000)
  );

  $: listFiatPrice = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: $user ? $user.fiat : $fiat,
    signDisplay: "never",
  }).format(
    list_price *
      100000000 *
      ($fiatRates[$user ? $user.fiat : $fiat] / 100000000)
  );

  $: reserveFiatPrice = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: $user ? $user.fiat : $fiat,
    signDisplay: "never",
  }).format(
    artwork.reserve_price * ($fiatRates[$user ? $user.fiat : $fiat] / 100000000)
  );

  $: inputFiatAmount = new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: $user ? $user.fiat : $fiat,
    signDisplay: "never",
  }).format(
    (amount
      ? tickerCalculated === "L-sats"
        ? amount
        : ticker === "L-BTC"
        ? amount * 100000000
        : 0
      : 0) *
      ($fiatRates[$user ? $user.fiat : $fiat] / 100000000)
  );

  $: tickerCalculated =
    ticker === "L-BTC" && $bitcoinUnitLocal === "sats" ? "L-sats" : ticker;

  $: listPrice =
    ticker === "L-BTC" && $bitcoinUnitLocal === "sats"
      ? satsFormatted(list_price * 100000000)
      : list_price;

  $: reservePrice =
    ticker === "L-BTC" && $bitcoinUnitLocal === "sats"
      ? satsFormatted(artwork.reserve_price)
      : val(artwork.reserve_price);

  $: bidAmount =
    ticker === "L-BTC" && $bitcoinUnitLocal === "sats"
      ? satsFormatted(artwork.bid && artwork.bid.amount)
      : val(artwork.bid && artwork.bid.amount);
</script>

<Head {metadata} />

<div class="container mx-auto mt-10 md:mt-20">
  <div class="flex flex-wrap">
    <div class="lg:text-left w-full lg:w-1/3 lg:max-w-xs">
      <h1 class="text-3xl font-black primary-color">
        {artwork.title || "Untitled"}
      </h1>
      <div class="flex mt-4 mb-6">
        <div class="my-auto">
          Edition
          {artwork.edition}
          of
          {artwork.editions}
        </div>
        {#if artwork.is_physical}
          <div
            class="flex ml-auto py-1 px-4 bg-gray-100 rounded rounded-full my-auto"
          >
            <div class="my-auto">
              <Fa icon={faImage} class="mr-1" />
            </div>
            <div class="my-auto mb-1">
              <span class="text-sm">Physical artwork</span>
            </div>
          </div>
        {/if}
      </div>

      <div class="flex flex-wrap justify-between text-left">
        <a href={`/${artwork.artist.username}`}>
          <div class="flex mb-6">
            <Avatar user={artwork.artist} />
            <div class="ml-2 secondary-color">
              <div>@{artwork.artist.username}</div>
              <div class="text-xs text-gray-600">Artist</div>
            </div>
          </div>
        </a>

        {#if artwork.artist_id !== artwork.owner_id}
          <a href={`/${artwork.owner.username}`}>
            <div class="flex mb-6 secondary-color">
              <Avatar user={artwork.owner} />
              <div class="ml-2">
                <div>@{artwork.owner.username}</div>
                <div class="text-xs text-gray-600">Owner</div>
              </div>
            </div>
          </a>
        {/if}
      </div>

      <div class="mobileImage">
        <span on:click={() => (showPopup = !showPopup)}>
          <Card {artwork} columns={1} showDetails={false} thumb={false} />
        </span>
      </div>

      <div class="flex justify-between mb-6">
        {#if artwork.list_price}
          <div class="my-2">
            <div class="text-sm mt-auto">List Price</div>
            <button
              on:click={() =>
                updateBitcoinUnit(
                  $bitcoinUnitLocal === "sats" ? "btc" : "sats"
                )}
              disabled={ticker !== "L-BTC"}
              class="text-lg text-left"
            >
              {listPrice}
              {tickerCalculated}
            </button>
            {#if ticker !== "L-CAD" && ticker !== "L-USDt"}
              <div class="text-sm">
                <Fiat amount={listFiatPrice} />
              </div>
            {/if}
          </div>
        {/if}
        {#if artwork.reserve_price}
          <div class="my-2">
            <div class="text-sm mt-auto">Reserve Price</div>
            <button
              on:click={() =>
                updateBitcoinUnit(
                  $bitcoinUnitLocal === "sats" ? "btc" : "sats"
                )}
              disabled={ticker !== "L-BTC"}
              class="flex-1 text-lg"
            >
              {reservePrice}
              {tickerCalculated}
            </button>
            {#if ticker !== "L-CAD" && ticker !== "L-USDt"}
              <div class="text-sm">
                <Fiat amount={reserveFiatPrice} />
              </div>
            {/if}
          </div>
        {/if}
        {#if artwork.bid && artwork.bid.amount}
          <div class="my-2">
            <div class="text-sm mt-auto">Current bid</div>
            <button
              on:click={() =>
                updateBitcoinUnit(
                  $bitcoinUnitLocal === "sats" ? "btc" : "sats"
                )}
              disabled={ticker !== "L-BTC"}
              class="text-lg"
            >
              {bidAmount}
              {tickerCalculated}
            </button>
            {#if ticker !== "L-CAD" && ticker !== "L-USDt"}
              <div class="text-sm">
                <Fiat amount={bidFiatAmount} />
              </div>
            {/if}
          </div>
        {/if}
      </div>

      <RoyaltyInfo {artwork} />

      {#if loading}
        <ProgressLinear />
      {:else if $session?.user?.id === artwork.owner_id}
        <div class="w-full mb-2">
          <a
            sveltekit:prefetch
            href={disabled ? "" : `/a/${artwork.slug}/auction`}
            class="block text-center text-sm secondary-btn w-full"
            class:disabled>List</a
          >
        </div>
        {#if artwork.held === "multisig" && !artwork.has_royalty && !artwork.auction_end}
          <div class="w-full mb-2">
            <a
              href="/"
              on:click|preventDefault={release}
              class="block text-center text-sm secondary-btn w-full"
              class:disabled>Release</a
            >
          </div>
        {/if}
        <div class="w-full mb-2">
          <a
            href={`/a/${artwork.slug}/transfer`}
            class="block text-center text-sm secondary-btn w-full"
            class:disabled>Transfer</a
          >
        </div>

        {#if $session?.user?.id === artwork.artist_id}
          <div class="w-full mb-2">
            <a
              href={`/a/${artwork.slug}/edit`}
              class="block text-center text-sm secondary-btn w-full"
              class:disabled>Edit</a
            >
          </div>
          <div class="w-full mb-2">
            <a
              href={"JavaScript:void(0)"}
              on:click={handleDelete}
              class="block text-center text-sm secondary-btn w-full cursor-pointer"
              >Delete</a
            >
          </div>
        {/if}
      {:else if artwork.asking_asset}
        {#if artwork.list_price}
          <button
            on:click={buyNow}
            class="secondary-btn"
            {disabled}
            class:disabled>Buy now</button
          >
        {/if}
        {#if bidding}
          {#if offering}
            <ProgressLinear />
          {:else}
            <form on:submit|preventDefault={makeOffer}>
              <div class="flex flex-col mb-4">
                <div>
                  <div class="mt-1 relative rounded-md shadow-sm">
                    <input
                      id="price"
                      class="form-input block w-full pl-7"
                      placeholder={val(0)}
                      bind:value={amount}
                      bind:this={amountInput}
                    />
                    <div
                      class="absolute inset-y-0 right-0 flex items-center mr-2"
                    >
                      {tickerCalculated}
                    </div>
                  </div>
                  {#if ticker !== "L-CAD" && ticker !== "L-USDt"}
                    <div class="flex justify-end">
                      <Fiat style="text-sm" amount={inputFiatAmount} />
                    </div>
                  {/if}
                </div>
              </div>
              <button type="submit" class="secondary-btn">Submit</button>
            </form>
          {/if}
        {:else if !artwork.auction_start || compareAsc(now, parseISO(artwork.auction_start)) === 1}
          <button
            on:click={startBidding}
            class="secondary-btn"
            {disabled}
            class:disabled>Make an offer</button
          >
        {/if}
      {/if}

      {#if compareAsc(parseISO(artwork.auction_start), now) === 1 && start_counter}
        <div class="bg-gray-100 px-4 p-1 mt-6 rounded">
          <div class="mt-auto text-sm">Auction starts in</div>
          <div class="mt-1">{start_counter}</div>
        </div>
      {/if}

      {#if compareAsc(parseISO(artwork.auction_end), now) === 1 && end_counter}
        <div class="bg-gray-100 px-4 p-1 mt-6 rounded">
          <div class="mt-auto text-sm">Auction closes in</div>
          <div class="mt-1">{end_counter}</div>
        </div>
      {:else if artwork.auction_end}
        <div class="bg-gray-100 px-4 p-1 mt-6 rounded">
          <div class="mt-auto text-sm">Auction ended at</div>
          <div class="mt-1">
            {format(parseISO(artwork.auction_end), "yyyy-MM-dd HH:mm")}
          </div>
        </div>
      {/if}

      <Sidebar bind:artwork />

      {#if artwork.description}
        <div
          class="mob-desc description text-gray-600 whitespace-pre-wrap"
        >
          <h4 class="mt-10 font-bold">About this artwork</h4>
          <div>
            {@html linkify(artwork.description)}
          </div>
        </div>
      {/if}

      <p class="font-bold mt-20">History</p>
      <div class="flex mt-5">
        <div class="w-full">
          {#each artwork.transactions.slice(0, showActivity ? artwork.transactions.length : 3) as transaction}
            <Activity {transaction} />
          {/each}
          {#if artwork.transactions.length > 3}
            <div
              class="flex text-xs cursor-pointer"
              on:click={() => (showActivity = !showActivity)}
            >
              <div>View {showActivity ? "less" : "more"}</div>
              <div class="my-auto ml-1">
                <Fa icon={showActivity ? faChevronUp : faChevronDown} />
              </div>
            </div>
          {/if}
        </div>
      </div>
    </div>

    <div class="w-full lg:w-2/3 lg:pl-40">
      <div class="desktopImage">
        <span on:click={() => (showPopup = !showPopup)}>
          <Card {artwork} columns={1} showDetails={false} thumb={false} />
        </span>
      </div>

      {#if artwork.description}
        <div class="desk-desc description text-gray-600">
          <h4 class="mt-10 mb-5 font-bold">About this artwork</h4>
          <div class="whitespace-pre-wrap">
            {@html linkify(artwork.description)}
          </div>
        </div>
      {/if}

      <div
        on:click={() => (showPopup = !showPopup)}
        class:showPopup
        class="popup"
      >
        <span class="closeButton"><Fa icon={faTimes} /></span>
        <Card
          {artwork}
          columns={1}
          showDetails={false}
          thumb={false}
          popup={true}
        />
      </div>

      <div class="mt-64">
        <Comments bind:artwork bind:refreshArtwork />
      </div>

      {#if others.length}
        <div class="w-full mb-4">
          <h2 class="text-2xl font-bold primary-color py-10 px-0">
            More by this artist
          </h2>
          <div class="w-full grid md:grid-cols-3 gap-4 others">
            {#each others as artwork (artwork.id)}
              <Card {artwork} showDetails={false} noAudio={true} />
            {/each}
          </div>
        </div>
        <div class="flex w-full">
          <a
            class="primary-btn mx-auto mb-12"
            href={`/artist/${artwork.artist.username}`}>View all</a
          >
        </div>
      {/if}
    </div>
  </div>
</div>

<style>
  :global(.description a) {
    color: #3ba5ac;
  }

  .disabled {
    pointer-events: none;
    @apply text-gray-400 border-gray-400;
  }

  button {
    @apply mb-2 w-full text-sm;
    &:hover {
      @apply border-green-700;
    }
  }

  .popup {
    position: fixed;
    z-index: 900;
    width: 100%;
    height: 100vh;
    padding: 5px;
    text-align: center;
    top: 0;
    left: 0;
    bottom: 0;
    right: 0;
    background: white;
    scroll-behavior: contain;
    transform: scale(0);
  }

  .showPopup {
    display: flex !important;
    align-items: center;
    justify-content: center;
    animation: zoom 0.2s ease forwards;
  }

  .closeButton {
    position: absolute;
    top: 50px;
    right: 50px;
    width: 40px;
    height: 40px;
    border-radius: 100%;
    background: whitesmoke;
    padding: 11px 15px;
    cursor: pointer;
  }

  .mob-desc {
    display: none;
  }

  .mobileImage {
    display: none;
    margin-bottom: 40px;
  }

  .mobileImage :global(.cover) {
    width: 100%;
  }

  .popup :global(video) {
    width: 50%;
    height: auto !important;
    margin: 0 auto;
  }

  .popup :global(div) {
    width: 100%;
    height: auto;
  }

  .popup :global(.card-link) {
    height: auto !important;
  }

  .popup :global(img) {
    margin: 0 auto;
    height: 95vh;
    object-fit: contain !important;
  }

  .desktopImage :global(img),
  .desktopImage :global(video) {
    margin: 0 auto;
  }

  @keyframes zoom {
    0% {
      transform: scale(0.6);
    }
    100% {
      transform: scale(1);
    }
  }

  @media only screen and (max-width: 1023px) {
    .desktopImage,
    .desk-desc {
      display: none;
    }

    .mobileImage,
    .mob-desc {
      display: block;
    }

    .closeButton {
      top: 20px;
      right: 20px;
    }
  }

  .others :global(img),
  .others :global(video) {
    height: 160px;
    width: 100%;
  }

  @media only screen and (max-width: 768px) {
    .popup :global(img),
    .popup :global(video) {
      height: auto;
      width: 100%;
    }

    .others :global(img),
    .others :global(video) {
      height: auto;
      width: 100%;
    }
  }
</style>
