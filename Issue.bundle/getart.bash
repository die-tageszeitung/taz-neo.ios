#<a href="VerzeichnisMenue.html">

let articleIndex=0

writeHeader() {
  let articleIndex=0
  echo "extension NavController {"
  echo "func setupArticles() {"
  echo "articles = []"
}

writeFooter() {
  echo "}"; echo "}"
}

writeFiles() {
  echo -n "sectionFiles = ["
  while test $# -gt 0
  do
    echo -n "\"$1\""
    if test $# -gt 1; then echo -n ", "; fi
    shift
  done
  echo "]"
}

writeSection2articles() {
  echo -n "section2articles[\"$1\"] = ["
  shift
  while test $# -gt 0
  do
    echo -n "$1"
    if test $# -gt 1; then echo -n ", "; fi
    shift
  done
  echo "]"
}

writeArticles() {
  writeSection2articles "$@"
  echo -n "articles.append(contentsOf: ["
  section="$1"
  shift
  let first=$articleIndex
  while test $# -gt 0
  do
    echo -n "$1"
    if test $# -gt 1; then echo -n ", "; fi
    shift
    let articleIndex++
  done
  let last=$articleIndex-1
  echo "])"
  echo "section2indices[\"$section\"] = ($first, $last)"
}

writeArticle2section() {
  section="$1"
  shift
  for a in "$@"
  do
    echo "article2section[$a] = \"$section\""
  done
}

patchArt() {
  section="$1"
  file="$2"
  sed -e '/ressort.css/s@<link rel="stylesheet" type="text/css" href="res/css/ressort.css"></link>@@' \
      -e '/platform.css/s@.css">@&<link rel="stylesheet" type="text/css" href="res/css/ressort.css"></link>@' \
      -e '/VerzeichnisKopf/s@<div class="VerzeichnisKopf".*2018</div>@@' \
      -e '/<div id="content">/s@>@><div class="VerzeichnisKopf">'"$section"'</div><div class="VerzeichnisDatum">freitag, 18. mai 2018</div>@' <$file >$file.new
}

patchFiles() {
  section="$1"
  shift
  for file in $@
  do
    eval "f=$file"
    if test "$f" != "dossier.datenschutz.html"
    then
      cp "$f" "$f".orig
      patchArt "$section" "$f"
      cp "$f".new "$f"
    fi
  done
}

resetFiles() {
  section="$1"
  shift
  for file in $@
  do
    eval "f=$file"
    if test "$f" != "dossier.datenschutz.html"
    then
      mv "$f".orig "$f"
      rm -f "$f".new
    fi
  done
}

files="seite1.html dossier.datenschutz.html inland.html wirtschaft.umwelt.html ausland.html meinung.diskussion.html taz.zwei.html kultur.html medien.html wissenschaft.html leibesuebungen.html wahrheit.html berlin.html nord.html art00045088.html"

isSource=""
isReset=""

if test "$isSource"
then
  writeHeader
  writeFiles $files
fi

for f in $files
do
  art=`fgrep .html "$f" | sed -n -e '/VerzeichnisMenue.html/d' -e 's/.*=\("[^"]*"\).*/\1/p'`
  sec=`sed -n -e '/VerzeichnisKopf/{' -e n -e 's/^ *//' -e p -e q -e '}' < "$f"`
  if test "$isSource"
  then
    writeArticles "$f" $art
    writeArticle2section "$f" $art
  else
    if test "$isReset"
    then
      resetFiles "$sec" $art
    else
      patchFiles "$sec" $art
    fi
  fi
done

if test "$isSource"
then
  writeFooter
fi
