class_name StoryLines
extends RefCounted
## Every line of the story that is written as an entry, keyed by the moment it belongs to.
## Each line: `text`; `hand`, whose hand writes it ("jekyll" or "hyde"); `by`, whose words
## they are (always "stevenson"); and `from`, the chapter of the book.
## Every line is Stevenson's words unchanged: a line may begin and end inside a sentence,
## but nothing within it is altered and nothing is added. A moment with no apt line has no key.
##
## LETTERS holds the letter shown at each of the four endings, as a list of parts in order:
## `text`, `hand`, `by` and `from` as for a line, and `role` ("greeting", "body" or
## "signature"). A part may be `struck` (a name with a stroke through it) or `broken` (the
## line stops short, and the pen rests before the next part). Each part is its own cut from
## the book; nothing is written between them.

const STATEMENT := "Henry Jekyll’s Full Statement of the Case"
const LANYON := "Dr. Lanyon’s Narrative"
const SEARCH := "Search for Mr. Hyde"
const LETTER := "Incident of the Letter"
const INCIDENT_LANYON := "Incident of Dr. Lanyon"
const LAST_NIGHT := "The Last Night"

const LINES := {
	# The run's first pages, and the draught.
	"opening.1": {
		"text": "man is not truly one, but truly two.",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"opening.2": {
		"text": "I had learned to dwell with pleasure, as a beloved daydream, on the thought of the separation of these elements.",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"opening.3": {
		"text": "If each, I told myself, could be housed in separate identities, life would be relieved of all that was unbearable; the unjust might go his way, delivered from the aspirations and remorse of his more upright twin",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"first_draught": {
		"text": "you who have denied the virtue of transcendental medicine, you who have derided your superiors—behold!",
		"hand": "hyde", "by": "stevenson", "from": LANYON,
	},
	# The five nights' openings.
	"night.1": {
		"text": "late one accursed night, I compounded the elements, watched them boil and smoke together in the glass, and when the ebullition had subsided, with a strong glow of courage, drank off the potion.",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"night.2": {
		"text": "whatever he had done, Edward Hyde would pass away like the stain of breath upon a mirror",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"night.3": {
		"text": "in my case, to be tempted, however slightly, was to fall.",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"night.4": {
		"text": "I looked down; my clothes hung formlessly on my shrunken limbs; the hand that lay on my knee was corded and hairy. I was once more Edward Hyde.",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"night.5": {
		"text": "My provision of the salt, which had never been renewed since the date of the first experiment, began to run low.",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	# Dawns: the laboratory's when Jekyll held the table, the back alley's when Hyde did.
	"dawn.1.lab": {
		"text": "I awoke in the morning shaken, weakened, but refreshed.",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"dawn.2.lab": {
		"text": "I was stepping leisurely across the court after breakfast, drinking the chill of the air with pleasure",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"dawn.3.lab": {
		"text": "I was once more at home, in my own house and close to my drugs",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"dawn.4.lab": {
		"text": "I still hated and feared the thought of the brute that slept within me",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"dawn.1.alley": {
		"text": "The night however, was far gone into the morning—the morning, black as it was, was nearly ripe for the conception of the day",
		"hand": "hyde", "by": "stevenson", "from": STATEMENT,
	},
	"dawn.2.alley": {
		"text": "I stole through the corridors, a stranger in my own house",
		"hand": "hyde", "by": "stevenson", "from": STATEMENT,
	},
	"dawn.3.alley": {
		"text": "the little room in Soho where I was accustomed to sleep in the body of Edward Hyde",
		"hand": "hyde", "by": "stevenson", "from": STATEMENT,
	},
	"dawn.4.alley": {
		"text": "thence I set out through the lamplit streets, in the same divided ecstasy of mind, gloating on my crime, light-headedly devising others in the future",
		"hand": "hyde", "by": "stevenson", "from": STATEMENT,
	},
	# The large moments.
	"arrival": {
		"text": "I knew myself, at the first breath of this new life, to be more wicked, tenfold more wicked, sold a slave to my original evil; and the thought, in that moment, braced and delighted me like wine.",
		"hand": "hyde", "by": "stevenson", "from": STATEMENT,
	},
	"breakout": {
		"text": "My devil had been long caged, he came out roaring.",
		"hand": "hyde", "by": "stevenson", "from": STATEMENT,
	},
	"window": {
		"text": "Yes, I had gone to bed Henry Jekyll, I had awakened Edward Hyde.",
		"hand": "hyde", "by": "stevenson", "from": STATEMENT,
	},
	# The four endings.
	"ending.jekyll": {
		"text": "This, too, was myself. It seemed natural and human.",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"ending.hyde": {
		"text": "like a schoolboy, strip off these lendings and spring headlong into the sea of liberty.",
		"hand": "hyde", "by": "stevenson", "from": STATEMENT,
	},
	"ending.succumbed": {
		"text": "I was slowly losing hold of my original and better self, and becoming slowly incorporated with my second and worse.",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
	"ending.unmet": {
		"text": "I chose the better part and was found wanting in the strength to keep to it.",
		"hand": "jekyll", "by": "stevenson", "from": STATEMENT,
	},
}


const LETTERS := {
	# He lives, and shuts his door.
	"jekyll": [
		{"text": "My dear Utterson,", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "greeting"},
		{"text": "I mean from henceforth to lead a life of extreme seclusion;", "hand": "jekyll", "by": "stevenson", "from": INCIDENT_LANYON, "role": "body"},
		{"text": "You must suffer me to go my own dark way.", "hand": "jekyll", "by": "stevenson", "from": INCIDENT_LANYON, "role": "body"},
		{"text": "you can do but one thing, Utterson, to lighten this destiny, and that is to respect my silence.", "hand": "jekyll", "by": "stevenson", "from": INCIDENT_LANYON, "role": "body"},
		{"text": "HENRY JEKYLL.", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "signature"},
	],
	# Hyde, safe in his mantle, writes to the man who saw him change.
	"hyde": [
		{"text": "Dear Lanyon,", "hand": "hyde", "by": "stevenson", "from": LANYON, "role": "greeting"},
		{"text": "I was the first that ever did so for his pleasures.", "hand": "hyde", "by": "stevenson", "from": STATEMENT, "role": "body"},
		{"text": "But for me, in my impenetrable mantle, the safety was complete.", "hand": "hyde", "by": "stevenson", "from": STATEMENT, "role": "body"},
		{"text": "Think of it—I did not even exist!", "hand": "hyde", "by": "stevenson", "from": STATEMENT, "role": "body"},
		{"text": "Edward Hyde", "hand": "hyde", "by": "stevenson", "from": LETTER, "role": "signature"},
	],
	# Jekyll's last note, broken off; Hyde steps into his shoes and signs over his name.
	"succumbed": [
		{"text": "My dear Utterson,", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "greeting"},
		{"text": "When this shall fall into your hands, I shall have disappeared", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "body", "broken": true},
		{"text": "the said Edward Hyde should step into the said Henry Jekyll’s shoes without further delay", "hand": "hyde", "by": "stevenson", "from": SEARCH, "role": "body"},
		{"text": "HENRY JEKYLL.", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "signature", "struck": true},
		{"text": "Edward Hyde", "hand": "hyde", "by": "stevenson", "from": LETTER, "role": "signature"},
	],
	# A composed order for the old salt that loses its composure.
	"unmet": [
		{"text": "Dr. Jekyll presents his compliments to Messrs. Maw.", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "greeting"},
		{"text": "He assures them that their last sample is impure and quite useless for his present purpose.", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "body"},
		{"text": "Expense is no consideration.", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "body"},
		{"text": "For God’s sake,", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "body", "broken": true},
		{"text": "find me some of the old.", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "body"},
		{"text": "HENRY JEKYLL.", "hand": "jekyll", "by": "stevenson", "from": LAST_NIGHT, "role": "signature"},
	],
}


## The line for `key`, or an empty Dictionary if there is none.
static func line(key: String) -> Dictionary:
	return LINES.get(key, {})


## The opening line of night `no` (1 to 5).
static func night(no: int) -> Dictionary:
	return line("night.%d" % no)


## The line for the dawn after night `no` (1 to 4), spent at `place` ("lab" or "alley").
static func dawn(no: int, place: String) -> Dictionary:
	return line("dawn.%d.%s" % [no, place])


## Every key in the table.
static func keys() -> Array:
	return LINES.keys()


## The letter for ending `id` ("jekyll", "hyde", "succumbed" or "unmet"), as its parts in
## order, or an empty Array if there is none.
static func letter(id: String) -> Array:
	return LETTERS.get(id, [])
