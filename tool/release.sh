#!/bin/bash
# Releases fPaint: sets the new version in pubspec.yaml, adds the release to
# CHANGELOG.md (one line per commit since the last release), runs
# tool/check.sh, then commits, tags and pushes. The pushed tag starts the
# Release workflow, which builds macOS, Windows and Linux and publishes them
# as the latest GitHub Release; running apps then offer the update.
#
# Usage: tool/release.sh <major|minor|patch|X.Y.Z>
#   patch  2.1.3 -> 2.1.4      minor  2.1.3 -> 2.2.0
#   major  2.1.3 -> 3.0.0      X.Y.Z  that exact version
# The build number (after the +) goes up by one on every release.
#
# Before answering y, you can edit the proposed entry: answer e to open it in
# $EDITOR (vi by default), e.g. to sort lines under ### Add / Change / Fix.

set -euo pipefail

cd "$(dirname "$0")/.."

RELEASE_BRANCH="main"
REMOTE="origin"
PUBSPEC="pubspec.yaml"
CHANGELOG="CHANGELOG.md"
VERSION_FILE="lib/models/version.dart"
# Files tool/check.sh regenerates; they go into the release commit
GENERATED=(coverage fcheck_files.svg fcheck_folders.svg fcheck_loc.svg fcheck_packages.svg test/output "$VERSION_FILE")
# The commits that only set a version, left out of the changelog
RELEASE_COMMIT='^Release v'

fail() {
	echo "Release stopped: $*" >&2
	exit 1
}

usage() {
	sed -n '/^# Usage:/,/^$/s/^# \{0,1\}//p' "$0" >&2
	exit 1
}

# Escapes the Markdown of each line outside its `code` spans, so a <tag>,
# a * or a \ in a commit subject shows as written
markdown_text() {
	awk -F'`' -v OFS='`' '{ for (i = 1; i <= NF; i += 2) gsub(/[\\<*]/, "\\\\&", $i); print }'
}

[ $# -eq 1 ] || usage

# --- The new version ----------------------------------------------------
current="$(sed -n 's/^version: *//p' "$PUBSPEC")"
[ -n "$current" ] || fail "no version in $PUBSPEC"
current_name="${current%%+*}"
current_build="0"
[[ "$current" == *+* ]] && current_build="${current#*+}"
IFS=. read -r major minor patch <<<"$current_name"

case "$1" in
	major) version="$((major + 1)).0.0" ;;
	minor) version="$major.$((minor + 1)).0" ;;
	patch) version="$major.$minor.$((patch + 1))" ;;
	[0-9]*.[0-9]*.[0-9]*)
		[[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage
		version="$1"
		;;
	*) usage ;;
esac
build="$((current_build + 1))"
tag="v$version"
previous_tag="v$current_name"

# --- The repository is ready ----------------------------------------------
[ "$(git branch --show-current)" = "$RELEASE_BRANCH" ] ||
	fail "releases are made from $RELEASE_BRANCH"
[ -z "$(git status --porcelain)" ] ||
	fail "commit or stash your changes first"
[ -f "$CHANGELOG" ] || fail "no $CHANGELOG"
git fetch --quiet --tags "$REMOTE" "$RELEASE_BRANCH"
# Commits not pushed yet go out with the release; commits only on the remote
# would get the push at the end rejected, after the long checks
git merge-base --is-ancestor "$REMOTE/$RELEASE_BRANCH" HEAD ||
	fail "$REMOTE/$RELEASE_BRANCH has commits $RELEASE_BRANCH lacks: pull first"

# The remote holds the releases: a tag found only here was never pushed, so
# it is left over from an earlier try and the release moves it
[ -z "$(git ls-remote --tags "$REMOTE" "refs/tags/$tag")" ] ||
	fail "$tag is already released on $REMOTE"
stale_tag="$(git log -1 --format='%h %s' "refs/tags/$tag" 2>/dev/null || true)"

# --- The changelog ----------------------------------------------------------
# Since the previous release's tag; before the first tagged release, since the
# commit that last set pubspec's version
if git rev-parse --quiet --verify "refs/tags/$previous_tag" >/dev/null; then
	since="$previous_tag"
else
	since="$(git log -1 --format=%H -G'^version:' -- "$PUBSPEC")"
	[ -n "$since" ] || fail "no tag $previous_tag and no commit setting $PUBSPEC's version"
	echo "No tag $previous_tag: listing the commits since $(git log -1 --format='%h %s' "$since")"
fi
git merge-base --is-ancestor "$since" HEAD ||
	fail "$since is not in $RELEASE_BRANCH's history"
changes="$(git log --no-merges --format='%s' "$since..HEAD" |
	{ grep -v "$RELEASE_COMMIT" || true; } | markdown_text | sed 's/^/- /')"
[ -n "$changes" ] || fail "nothing to release: no commits since $since"
section="## [$version] - $(date +%Y-%m-%d)

### Change

$changes"

while true; do
	printf '\n%s\n\n' "$section"
	[ -z "$stale_tag" ] ||
		echo "Tag $tag, never pushed, moves from $stale_tag to this release"
	printf 'Release %s -> %s+%s with this %s entry, tagged %s? [y/N/e=edit] ' \
		"$current" "$version" "$build" "$CHANGELOG" "$tag"
	read -r answer
	case "$answer" in
		[Yy]) break ;;
		[Ee])
			draft="$(mktemp)"
			printf '%s\n' "$section" >"$draft"
			"${EDITOR:-vi}" "$draft"
			section="$(cat "$draft")"
			rm -f "$draft"
			;;
		*) fail "cancelled" ;;
	esac
done

# --- Set the version and the changelog, then check -------------------------
# Until the commit, any failure puts the files back as they were
restore() {
	git checkout --quiet -- "$PUBSPEC" "$CHANGELOG"
	git checkout --quiet -- "${GENERATED[@]}" 2>/dev/null || true
}
trap restore EXIT
sed -i.bak "s/^version: .*/version: $version+$build/" "$PUBSPEC"
rm "$PUBSPEC.bak"
# The new release goes above the one before, under the file's introduction
SECTION="$section" awk '
	!added && /^## / { print ENVIRON["SECTION"]; print ""; added = 1 }
	{ print }
	END { if (!added) { print ""; print ENVIRON["SECTION"] } }
' "$CHANGELOG" >"$CHANGELOG.new"
mv "$CHANGELOG.new" "$CHANGELOG"

echo "--- Checks (tool/check.sh)"
tool/check.sh

excludes=(":(exclude)$PUBSPEC" ":(exclude)$CHANGELOG")
for path in "${GENERATED[@]}"; do
	excludes+=(":(exclude)$path")
done
others="$(git status --porcelain -- . "${excludes[@]}")"
[ -z "$others" ] ||
	fail "the checks changed more than the release files: $(echo "$others" | tr '\n' ' ')"

# --- Commit, tag and push ----------------------------------------------------
git add -- "$PUBSPEC" "$CHANGELOG" "${GENERATED[@]}"
git commit --quiet -m "Release $tag"
trap - EXIT
# --force moves a tag never pushed (stale_tag); one on the remote stopped above
git tag --force -a "$tag" -m "fPaint $version" >/dev/null
git push --atomic "$REMOTE" "$RELEASE_BRANCH" "$tag" ||
	fail "push failed; $tag is committed and tagged here, retry with: git push --atomic $REMOTE $RELEASE_BRANCH $tag"

echo "Released $tag: the Release workflow now builds and publishes it"
echo "https://github.com/vteam-com/fPaint/actions/workflows/release.yml"
