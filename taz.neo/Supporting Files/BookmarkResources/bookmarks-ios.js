/*
 *  JS functions for taz bookmarks in iOS
 */

/* Defines class name of element with id */
function setClass(clname, id = "content") {
  let elem = document.getElementById(id);
  elem.classname = mode;
}

/* Define padding of CSS selector */
function setPadding(padding, selector = "body") {
  let sel = document.querySelector(selector);
  sel.style.padding = wpadding;
}

/* Define font size of CSS selector */
function setFontSize(val, selector = "html") {
  let sel = document.querySelector(selector);
  sel.style.fontSize = val;
}

/* Define text alignment of CSS selector */
function setTextAlign(val, selector = "p") {
  let sel = document.querySelector(selector);
  sel.style.textAlign = val;
}

/* Shrink article to height 0 */
function shrink(art) {
  let currentHeight = art.scrollHeight;
  let trans = art.style.transition;
  art.style.transition = "";
  requestAnimationFrame(() => {
    art.style.height = currentHeight + "px";
    art.style.transition = trans;
    requestAnimationFrame(() => {
      art.style.height = "0px";
    });
  });
}

function resetArticleHeight(event) {
  let art = event.target;
  art.style.height = "auto";  
  art.removeEventListener("transitionend", resetArticleHeight);
}

/* Grow article to its scrollHeight (ie. the size needed to display it) */
function grow(art) {
  art.addEventListener("transitionend", resetArticleHeight);
  let sheight = art.scrollHeight;
  let trans = art.style.transition;
  art.style.transition = "";
  requestAnimationFrame(() => {
    art.style.height = "0px";
    art.style.transition = trans;
    requestAnimationFrame(() => {
      art.style.height = sheight + "px";
    });
  });
}

function reallyDeleteBookmark(event) {
  let art = event.target;
  const title = art.querySelector("h2").textContent;
  tazApi.toast("<h3>" + title + "</h3>" + "Löschen rückgängig durch Antippen",
    3.0, (wasTapped) => {
    console.log("wasTapped: " + wasTapped);
    if (wasTapped) {
      let rect = art.getBoundingClientRect();
      if (rect.height <= 2) { grow(art); }
    }
    else {
      art.remove();
      tazApi.setBookmark(art.id + ".html", false);
    }
  });
  art.removeEventListener("transitionend", reallyDeleteBookmark);
}

/* Delete bookmark */
function deleteBookmark(elem) {
  const art = elem.parentElement.parentElement.parentElement;
  art.addEventListener("transitionend", reallyDeleteBookmark);
  shrink(art);
}

function insertArticle(html, id, order) {
  let art = docment.createElement("article");
  art.id = id;
  art.innerHTML = html;
  art.style.height = "0px";
  art.style.order = order;
  let content = document.getElementbyId("content");
  content.appendChild(art);
  grow(art);
}

/* Share Article */
function shareArticle(elem) {
  const art = elem.parentElement.parentElement.parentElement;
  tazApi.shareArticle(art.id + ".html");
}

/* Set up click functions for share and trash icons */
function setupButtons() {
  for (let b of document.getElementsByClassName("trash")) {
    b.addEventListener("click", (event) => {
      event.preventDefault();
      deleteBookmark(event.target);
    });
  }
  for (let b of document.getElementsByClassName("share")) {
    b.addEventListener("click", (event) => {
      event.preventDefault();
      shareArticle(event.target);
    });
  }
}

/* Read settings from localStorage */
function readSettings() {
  let val = localStorage.getItem("tazApi.colorTheme");
  if (val) { setClass(val); }
  if (val = localStorage.getItem("tazApi.padding"))
    { setPadding(val); }
  if (val = localStorage.getItem("tazApi.fontSize"))
    { setFontSize(val); }
  if (val = localStorage.getItem("tazApi.textAlign"))
    { setTextAlign(val); }
}

/* Functions used from the native side */ 

/* Set the color theme to use, either "light" or "dark" */
tazApi.setColorTheme = (theme) => {
  localStorage.setItem("tazApi.colorTheme", theme);
  setClass(theme);
}

/* Set padding of body, eg. "10px 15px 20px 30px" */
tazApi.setPadding = (padding) => {
  localStorage.setItem("tazApi.padding", padding);
  setPadding(padding);
}

/* Set font-size of html element (define root em) */
tazApi.setFontSize = (fsize) => {
  localStorage.setItem("tazApi.fontSize", fsize);
  setFontSize(fsize);
}

/* Set text alignment of p elements */
tazApi.setTextAlign = (alignment) => {
  localStorage.setItem("tazApi.textAlign", alignment);
  setTextAlign(alignment);
}

/* Indicates that we can handle CSS change requests */
tazApi.hasDynamicCSS = () => { return true; }

/* Initialize CSS and setup buttons when DOM is ready */
document.addEventListener("DOMContentLoaded", (e) => {
  readSettings();
  setupButtons();
});
