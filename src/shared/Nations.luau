--!strict
-- Where a footballer comes from: a code, a flag and the names that go with it.
-- Pure and deterministic given a Random. Every name is a common first name and
-- a common surname from that country put together at random - never a real
-- player (CLAUDE.md s3: fictional players only).
--
-- `reach` (0..1) is how far the net is cast. A grassroots squad, the academy
-- and a Local Scout are reach 0 and find almost everybody at home; a
-- Continental Network is reach 1 and finds most of its players abroad.
-- All weights are TEMP.

local Nations = {}

-- A flag as the UI can draw it from Frames: stripes, plus at most one emblem.
--   dir     "v" = vertical stripes left to right, "h" = horizontal top to bottom
--   colors  one per stripe
--   sizes   relative stripe sizes (equal when nil)
--   emblem  "cross" (upright), "saltire" (diagonal), "disc", "diamond",
--           "canton" (a block in the top-left corner)
export type Flag = {
	dir: "v" | "h",
	colors: { Color3 },
	sizes: { number }?,
	emblem: string?,
	emblemColor: Color3?,
}

export type Nation = {
	code: string,
	name: string,
	home: boolean, -- Britain and Ireland: the clubs are all from Rivermere
	weight: number,
	flag: Flag,
	first: { string },
	last: { string },
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local WHITE, BLACK = rgb(255, 255, 255), rgb(20, 20, 20)
local RED, GREEN, YELLOW = rgb(206, 17, 38), rgb(0, 140, 69), rgb(252, 209, 22)
local SKY = rgb(116, 172, 223)

Nations.HOME = "ENG"

Nations.LIST = {
	{
		code = "ENG", name = "England", home = true, weight = 60,
		flag = { dir = "h", colors = { WHITE }, emblem = "cross", emblemColor = RED },
		first = { "Alfie", "Callum", "Finn", "Gus", "Harvey", "Jaxon", "Levi", "Noah", "Oscar", "Sonny", "Theo", "Vinnie", "Wes", "Zack", "Kit", "Teddy", "Blaze", "Rocco" },
		last = { "Abbott", "Brookes", "Cantwell", "Dunmore", "Ellery", "Fairweather", "Goss", "Ings", "Jarvis", "Kettering", "Lomax", "Pickering", "Sowerby", "Thorne", "Underhill", "Wickham", "Yarrow", "Bloxham", "Noobington", "Skyward", "Fairbanks" },
	},
	{
		code = "SCO", name = "Scotland", home = true, weight = 10,
		flag = { dir = "h", colors = { rgb(0, 94, 184) }, emblem = "saltire", emblemColor = WHITE },
		first = { "Angus", "Callan", "Dougie", "Ewan", "Fraser", "Hamish", "Innes", "Lachlan", "Murray", "Rory", "Struan", "Blair" },
		last = { "Baird", "Cairns", "Dalgleish", "Forsyth", "Geddes", "Kinnear", "Lennox", "MacAulay", "McCrae", "Ogilvie", "Rennie", "Tulloch" },
	},
	{
		code = "WAL", name = "Wales", home = true, weight = 8,
		flag = { dir = "h", colors = { WHITE, GREEN }, emblem = "disc", emblemColor = RED },
		first = { "Aled", "Bryn", "Cai", "Dylan", "Emrys", "Gethin", "Ifan", "Llew", "Osian", "Rhys", "Tomos", "Macsen" },
		last = { "Bevan", "Cadogan", "Griffiths", "Howells", "Llewellyn", "Maddox", "Penry", "Probert", "Pugh", "Rees", "Vaughan", "Wynne" },
	},
	{
		code = "NIR", name = "Northern Ireland", home = true, weight = 4,
		flag = { dir = "h", colors = { WHITE }, emblem = "cross", emblemColor = rgb(200, 16, 46) },
		first = { "Aaron", "Conall", "Corey", "Darragh", "Eoin", "Jude", "Kyle", "Ronan", "Shea", "Tiernan", "Caolan", "Ethan" },
		last = { "Boyd", "Carlisle", "Devlin", "Gilmore", "Hanna", "Irvine", "Magill", "McAuley", "Nesbitt", "Orr", "Quigley", "Sproule" },
	},
	{
		code = "IRL", name = "Ireland", home = true, weight = 8,
		flag = { dir = "v", colors = { rgb(22, 155, 98), WHITE, rgb(255, 136, 62) } },
		first = { "Cian", "Cillian", "Conor", "Declan", "Fionn", "Niall", "Oisin", "Padraig", "Ruairi", "Senan", "Tadhg", "Donal" },
		last = { "Brennan", "Cassidy", "Doherty", "Fogarty", "Hartigan", "Kinsella", "Lalor", "Moloney", "Nolan", "Quinlan", "Roche", "Tierney" },
	},
	{
		code = "FRA", name = "France", home = false, weight = 12,
		flag = { dir = "v", colors = { rgb(0, 38, 153), WHITE, rgb(237, 41, 57) } },
		first = { "Adrien", "Bastien", "Corentin", "Damien", "Enzo", "Florian", "Hugo", "Killian", "Loïc", "Mathis", "Rémi", "Yanis" },
		last = { "Moreau", "Girard", "Lefèvre", "Roussel", "Fontaine", "Chevalier", "Marchand", "Dumas", "Perrin", "Barbier", "Renaud", "Colin" },
	},
	{
		code = "ESP", name = "Spain", home = false, weight = 11,
		flag = { dir = "h", colors = { rgb(198, 11, 30), rgb(255, 196, 0), rgb(198, 11, 30) }, sizes = { 1, 2, 1 } },
		first = { "Adrián", "Borja", "César", "Dani", "Hugo", "Iker", "Javi", "Martín", "Nico", "Pablo", "Rafa", "Xavi" },
		last = { "Alonso", "Blanco", "Castillo", "Delgado", "Gallego", "Herrero", "Lozano", "Marín", "Ortega", "Pascual", "Rubio", "Vidal" },
	},
	{
		code = "ITA", name = "Italy", home = false, weight = 9,
		flag = { dir = "v", colors = { rgb(0, 146, 70), WHITE, rgb(206, 43, 55) } },
		first = { "Alessio", "Dario", "Emanuele", "Fabio", "Gianluca", "Jacopo", "Luca", "Matteo", "Nicolò", "Pietro", "Riccardo", "Simone" },
		last = { "Bianchi", "Colombo", "De Luca", "Ferri", "Galli", "Lombardi", "Marchetti", "Pellegrino", "Rinaldi", "Santoro", "Testa", "Vitale" },
	},
	{
		code = "GER", name = "Germany", home = false, weight = 9,
		flag = { dir = "h", colors = { BLACK, rgb(221, 0, 0), rgb(255, 206, 0) } },
		first = { "Anton", "Bastian", "Erik", "Felix", "Jonas", "Lennart", "Moritz", "Niklas", "Ole", "Paul", "Till", "Yannick" },
		last = { "Becker", "Brandt", "Engel", "Fuchs", "Hartmann", "Keller", "Lange", "Roth", "Schubert", "Vogel", "Winkler", "Ziegler" },
	},
	{
		code = "NED", name = "Netherlands", home = false, weight = 7,
		flag = { dir = "h", colors = { rgb(174, 28, 40), WHITE, rgb(33, 70, 139) } },
		first = { "Bram", "Daan", "Finn", "Jesse", "Lars", "Mees", "Niels", "Ruben", "Sem", "Thijs", "Timo", "Wout" },
		last = { "Bakker", "Bos", "Brouwer", "Dekker", "Hendriks", "Jacobs", "Maas", "Mulder", "Peters", "Smits", "Visser", "Vos" },
	},
	{
		code = "POR", name = "Portugal", home = false, weight = 7,
		flag = { dir = "v", colors = { rgb(0, 102, 0), rgb(255, 0, 0) }, sizes = { 2, 3 }, emblem = "disc", emblemColor = YELLOW },
		first = { "Afonso", "Duarte", "Fábio", "Gonçalo", "Hélder", "Ivo", "Lourenço", "Miguel", "Nuno", "Rúben", "Tiago", "Vasco" },
		last = { "Almeida", "Barros", "Cardoso", "Esteves", "Faria", "Lopes", "Machado", "Nogueira", "Pinto", "Ramos", "Tavares", "Vieira" },
	},
	{
		code = "BRA", name = "Brazil", home = false, weight = 9,
		flag = { dir = "h", colors = { rgb(0, 155, 58) }, emblem = "diamond", emblemColor = rgb(254, 223, 0) },
		first = { "Anderson", "Caio", "Davi", "Everton", "Felipe", "Gustavo", "Igor", "Luan", "Matheus", "Renan", "Thiago", "Wesley" },
		last = { "Araújo", "Barbosa", "Cavalcanti", "Duarte", "Freitas", "Lima", "Moraes", "Nascimento", "Queiroz", "Rezende", "Teixeira", "Xavier" },
	},
	{
		code = "ARG", name = "Argentina", home = false, weight = 7,
		flag = { dir = "h", colors = { SKY, WHITE, SKY }, emblem = "disc", emblemColor = rgb(246, 180, 14) },
		first = { "Agustín", "Bruno", "Ezequiel", "Facundo", "Gastón", "Joaquín", "Lautaro", "Matías", "Nahuel", "Ramiro", "Santino", "Tomás" },
		last = { "Acosta", "Benítez", "Cabrera", "Domínguez", "Figueroa", "Godoy", "Ledesma", "Medina", "Navarro", "Peralta", "Quiroga", "Sosa" },
	},
	{
		code = "NGA", name = "Nigeria", home = false, weight = 7,
		flag = { dir = "v", colors = { rgb(0, 135, 81), WHITE, rgb(0, 135, 81) } },
		first = { "Chidi", "Emeka", "Femi", "Ifeanyi", "Kelechi", "Nnamdi", "Obinna", "Segun", "Tobi", "Uche", "Wale", "Yemi" },
		last = { "Adeyemi", "Balogun", "Chukwu", "Eze", "Ibekwe", "Lawal", "Nwosu", "Oduya", "Okafor", "Olawale", "Onuoha", "Uzor" },
	},
	{
		code = "GHA", name = "Ghana", home = false, weight = 5,
		flag = { dir = "h", colors = { rgb(206, 17, 38), YELLOW, rgb(0, 107, 63) }, emblem = "disc", emblemColor = BLACK },
		first = { "Kofi", "Kwame", "Kojo", "Yaw", "Kwesi", "Nana", "Ebo", "Fiifi", "Kwabena", "Akwasi", "Ato", "Paa" },
		last = { "Addo", "Amoah", "Ansah", "Boakye", "Danso", "Frimpong", "Kyei", "Mensah", "Ofori", "Owusu", "Quaye", "Tetteh" },
	},
	{
		code = "POL", name = "Poland", home = false, weight = 6,
		flag = { dir = "h", colors = { WHITE, rgb(220, 20, 60) } },
		first = { "Bartek", "Dawid", "Filip", "Igor", "Jakub", "Kacper", "Marcel", "Oskar", "Patryk", "Szymon", "Tymon", "Wiktor" },
		last = { "Adamski", "Borkowski", "Czarnecki", "Górski", "Jasiński", "Kubiak", "Laskowski", "Majewski", "Nowicki", "Pawlak", "Sikora", "Zelinski" },
	},
	{
		code = "JPN", name = "Japan", home = false, weight = 5,
		flag = { dir = "h", colors = { WHITE }, emblem = "disc", emblemColor = rgb(188, 0, 45) },
		first = { "Daiki", "Haruto", "Kaito", "Kenta", "Ren", "Riku", "Shota", "Sota", "Takumi", "Yuma", "Yuto", "Hiro" },
		last = { "Aoki", "Fujita", "Hayashi", "Ishii", "Kimura", "Matsuda", "Nishida", "Ogawa", "Sakai", "Takeda", "Ueno", "Yamada" },
	},
	{
		code = "USA", name = "United States", home = false, weight = 5,
		flag = { dir = "h", colors = { rgb(178, 34, 52), WHITE, rgb(178, 34, 52), WHITE, rgb(178, 34, 52) }, emblem = "canton", emblemColor = rgb(60, 59, 110) },
		first = { "Austin", "Brady", "Chase", "Cody", "Dev", "Hunter", "Jalen", "Mason", "Quinn", "Tanner", "Tyler", "Zeke" },
		last = { "Barrett", "Calloway", "Dawson", "Easton", "Hollis", "Keating", "Landry", "Mercer", "Prescott", "Ridley", "Sutter", "Whitlock" },
	},
} :: { Nation }

local BY_CODE: { [string]: Nation } = {}
for _, n in Nations.LIST do
	BY_CODE[n.code] = n
end

-- TEMP: how much of the net lands abroad. Home weights add up to 90 and the
-- foreign ones to about 100, so reach 0 is about 1 in 10 abroad and reach 1
-- about 6 in 10.
local FOREIGN_SCALE_NEAR, FOREIGN_SCALE_FAR = 0.1, 1.5

function Nations.get(code: string?): Nation
	return (if code then BY_CODE[code] else nil) or BY_CODE[Nations.HOME]
end

function Nations.pick(rng: Random, reach: number?): Nation
	local r = math.clamp(reach or 0, 0, 1)
	local scale = FOREIGN_SCALE_NEAR + (FOREIGN_SCALE_FAR - FOREIGN_SCALE_NEAR) * r
	local total = 0
	for _, n in Nations.LIST do
		total += if n.home then n.weight else n.weight * scale
	end
	local roll = rng:NextNumber() * total
	for _, n in Nations.LIST do
		roll -= if n.home then n.weight else n.weight * scale
		if roll <= 0 then
			return n
		end
	end
	return BY_CODE[Nations.HOME]
end

function Nations.nameFor(rng: Random, nation: Nation): string
	return nation.first[rng:NextInteger(1, #nation.first)] .. " " .. nation.last[rng:NextInteger(1, #nation.last)]
end

-- Players saved before nationality existed: a stable code from the id and the
-- name (FNV-1a, like Squad.lookSeedFor), spread like a reach-0 squad.
function Nations.codeFor(id: number, name: string): string
	local h = 2166136261
	for i = 1, #name do
		h = (bit32.bxor(h, name:byte(i)) * 16777619) % 2 ^ 31
	end
	return Nations.pick(Random.new((h + id * 7919) % 2 ^ 30 + 1), 0).code
end

return Nations
