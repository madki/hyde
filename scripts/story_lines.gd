class_name StoryLines
extends RefCounted
## Every line of the story that is written as an entry, keyed by the moment it belongs to.
## Each line: `text`; `hand`, whose hand writes it ("jekyll" or "hyde"); `by`, whose words
## they are ("stevenson" or "ours"); and `from`, the chapter of the book for Stevenson's.
## Stevenson's lines are his words unchanged: a line may begin and end inside a sentence,
## but nothing within it is altered. The dawn lines are ours.

const STATEMENT := "Henry Jekyll’s Full Statement of the Case"
const LANYON := "Dr. Lanyon’s Narrative"

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
		"text": "I held the table until morning, and I spend the dawn in my laboratory, setting the glasses in order.",
		"hand": "jekyll", "by": "ours", "from": "",
	},
	"dawn.2.lab": {
		"text": "The night was mine, though he was hunted through it, and I spend the dawn in my laboratory with the door locked.",
		"hand": "jekyll", "by": "ours", "from": "",
	},
	"dawn.3.lab": {
		"text": "I kept the table through the worst of nights, and the dawn finds me in my laboratory, washing my hands.",
		"hand": "jekyll", "by": "ours", "from": "",
	},
	"dawn.4.lab": {
		"text": "I held the table to the end, and I spend this grey dawn in my laboratory, counting what salt is left.",
		"hand": "jekyll", "by": "ours", "from": "",
	},
	"dawn.1.alley": {
		"text": "The table was mine, not the doctor’s, and I spend the dawn in the back alley, where nobody asks my name.",
		"hand": "hyde", "by": "ours", "from": "",
	},
	"dawn.2.alley": {
		"text": "They hunted me all night and still the table was mine, so I spend the dawn in the back alley, laughing.",
		"hand": "hyde", "by": "ours", "from": "",
	},
	"dawn.3.alley": {
		"text": "The table was mine by the end of it, and the dawn finds me in the back alley with half a cane in my coat.",
		"hand": "hyde", "by": "ours", "from": "",
	},
	"dawn.4.alley": {
		"text": "I held the table and the doctor never woke, so I spend the dawn in the back alley, in clothes too large for me.",
		"hand": "hyde", "by": "ours", "from": "",
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
