---
layout: page
title: Searchable List of Bluey Episodes
---

<input type="text" id="searchBox" placeholder="Search episodes..." style="width: 100%; padding: 8px; margin-bottom: 16px; font-size: 16px; border: 1px solid #ccc; border-radius: 4px;">
<style>
li.hidden {
  visibility: hidden;
  position: absolute;
  left: -9999px;
}
</style>
<h2 id="season1">Season 1</h2>
<ol class="episode-list">
<li>Magic Xylophone</li>
<li>Hospital</li>
<li>Keepy Uppy</li>
<li>Daddy Robot</li>
<li>Shadowlands</li>
<li>The Weekend</li>
<li>BBQ</li>
<li>Fruitbat</li>
<li>Horsey Ride</li>
<li>Hotel</li>
<li>Bike</li>
<li>Bob Bilby</li>
<li>Spy Game</li>
<li>Takeaway</li>
<li>Butterflies</li>
<li>Yoga Ball</li>
<li>Calypso</li>
<li>The Doctor</li>
<li>The Claw</li>
<li>Markets</li>
<li>Blue Mountains</li>
<li>The Pool</li>
<li>Shops</li>
<li>Wagon Ride</li>
<li>Taxi</li>
<li>The Beach</li>
<li>Pirates</li>
<li>Grannies</li>
<li>The Creek</li>
<li>Fairies</li>
<li>Work</li>
<li>Bumpy and the Wise Old Wolfhound</li>
<li>Trampoline</li>
<li>The Dump</li>
<li>Zoo</li>
<li>Backpackers</li>
<li>The Adventure</li>
<li>Copycat</li>
<li>The Sleepover</li>
<li>Early Baby</li>
<li>Mums and Dads</li>
<li>Hide and Seek</li>
<li>Camping</li>
<li>Mount Mumandad</li>
<li>Kids</li>
<li>Chickenrat</li>
<li>Neighbours</li>
<li>Teasing</li>
<li>Asparagus</li>
<li>Shaun</li>
<li>Daddy Putdown</li>
<li>Verandah Santa</li>
</ol>

<h2 id="season2">Season 2</h2>
<ol class="episode-list">
<li>Dance Mode</li>
<li>Hammerbarn</li>
<li>Featherwand</li>
<li>Squash</li>
<li>Hairdressers</li>
<li>Stumpfest</li>
<li>Favourite Thing</li>
<li>Daddy Dropoff</li>
<li>Bingo</li>
<li>Rug Island</li>
<li>Charades</li>
<li>Sticky Gecko</li>
<li>Dad Baby</li>
<li>Mum School</li>
<li>Trains</li>
<li>Army</li>
<li>Fancy Restaurant</li>
<li>Piggyback</li>
<li>The Show</li>
<li>Tickle Crabs</li>
<li>Escape</li>
<li>Bus</li>
<li>Queens</li>
<li>Flat Pack</li>
<li>Helicopter</li>
<li>Sleepytime</li>
<li>Grandad</li>
<li>Seesaw</li>
<li>Movies</li>
<li>Library</li>
<li>Barky Boats</li>
<li>Burger Shop</li>
<li>Circus</li>
<li>Swim School</li>
<li>Cafe</li>
<li>Postman</li>
<li>The Quiet Game</li>
<li>Mr Monkeyjocks</li>
<li>Double Babysitter</li>
<li>Bad Mood</li>
<li>Octopus</li>
<li>Bin Night</li>
<li>Muffin Cone</li>
<li>Duck Cake</li>
<li>Handstand</li>
<li>Road Trip</li>
<li>Ice Cream</li>
<li>Dunny</li>
<li>Typewriter</li>
<li>Baby Race</li>
<li>Christmas Swim</li>
<li>Easter</li>
</ol>

<h2 id="season3">Season 3</h2>
<ol class="episode-list">
<li>Perfect</li>
<li>Bedroom</li>
<li>Obstacle Course</li>
<li>Promises</li>
<li>Omelette</li>
<li>Born Yesterday</li>
<li>Mini Bluey</li>
<li>Unicorse</li>
<li>Curry Quest</li>
<li>Magic</li>
<li>Chest</li>
<li>Sheepdog</li>
<li>Housework</li>
<li>Pass the Parcel</li>
<li>Explorers</li>
<li>Phones</li>
<li>Pavlova</li>
<li>Rain</li>
<li>Pizza Girls</li>
<li>Driving</li>
<li>Tina</li>
<li>Whale Watching</li>
<li>Family Meeting</li>
<li>Faceytalk</li>
<li>Ragdoll</li>
<li>Fairytale</li>
<li>Musical Statues</li>
<li>Stories</li>
<li>Puppets</li>
<li>Turtleboy</li>
<li>Onesies</li>
<li>Tradies</li>
<li>Granny Mobile</li>
<li>Space</li>
<li>Smoochy Kiss</li>
<li>Dirt</li>
<li>The Decider</li>
<li>Cubby</li>
<li>Exercise</li>
<li>Relax</li>
<li>Stickbird</li>
<li>Show And Tell</li>
<li>Dragon</li>
<li>Wild Girls</li>
<li>TV Shop</li>
<li>Slide</li>
<li>Cricket</li>
<li>Ghostbasket</li>
<li>The Sign</li>
<li>Surprise</li>
</ol>

<script>
const searchBox = document.getElementById('searchBox');
const episodeLists = Array.from(document.getElementsByClassName('episode-list'));
const allItems = episodeLists.flatMap(list => Array.from(list.getElementsByTagName('li')));

// Prepopulate search box from URL hash
const initialQuery = decodeURIComponent(location.hash.slice(1));
if (initialQuery) {
    searchBox.value = initialQuery;
} else {
    searchBox.focus();
}

function fuzzyMatch(query, text) {
    query = query.toLowerCase();
    text = text.toLowerCase();
    let queryIndex = 0;
    let textIndex = 0;
    
    while (queryIndex < query.length && textIndex < text.length) {
        if (query[queryIndex] === text[textIndex]) {
            queryIndex++;
        }
        textIndex++;
    }
    
    return queryIndex === query.length;
}

function filterEpisodes(query) {
    episodeLists.forEach(list => {
        const items = Array.from(list.getElementsByTagName('li'));
        let hasVisibleItems = false;
        items.forEach(item => {
            if (query === '' || fuzzyMatch(query, item.textContent)) {
                item.classList.remove('hidden');
                hasVisibleItems = true;
            } else {
                item.classList.add('hidden');
            }
        });
        const header = list.previousElementSibling;
        if (header && header.tagName === 'H2') {
            header.style.display = hasVisibleItems ? '' : 'none';
        }
        list.style.display = hasVisibleItems ? '' : 'none';
    });
}

// Initial filter on page load
filterEpisodes(searchBox.value);

searchBox.addEventListener('input', function() {
    const query = this.value;
    // Update URL hash as user types
    location.hash = encodeURIComponent(query);
    filterEpisodes(query);
});
</script>
