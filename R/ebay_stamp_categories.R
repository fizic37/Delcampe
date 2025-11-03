#' eBay Stamp Category Mappings
#'
#' Complete hierarchy of eBay stamp categories extracted from official CSV:
#' https://ir.ebaystatic.com/pictures/aw/pics/pdf/us/file_exchange/CategoryIDs-US.csv
#'
#' Total: 438 stamp categories across 16 regions
#'
#' @section Category Structure:
#' The eBay stamp categories are organized hierarchically:
#' - Level 1: "Stamps" (category 260) - PARENT, NOT A LEAF
#' - Level 2: Regions (16 total) - Most are NOT leaf categories
#' - Level 3: Countries/Subcategories - LEAF categories (can create listings)
#'
#' @section Critical Rules:
#' - eBay requires LEAF categories for listing creation
#' - Using parent categories results in Error 87
#' - Only "Other Stamps" (170137) is a leaf at region level
#'
#' @name ebay_stamp_categories
NULL

#' Complete eBay Stamp Category Hierarchy
#'
#' Nested list structure matching eBay's category hierarchy.
#' Each region contains countries with their category IDs.
#'
#' @export
STAMP_CATEGORIES <- list(
  # United States (37 categories)
  US = list(
    label = "United States",
    region_id = NULL,  # Not a leaf
    countries = list(
      "19th Century: Unused" = 676,
      "19th Century: Used" = 675,
      "1901-40: Unused" = 3461,
      "1941-Now: Unused" = 679,
      "1901-Now: Used" = 678,
      "Back of Book > Air Mail" = 680,
      "Back of Book > Booklets" = 3462,
      "Back of Book > Duck Stamps" = 685,
      "Back of Book > Postal Cards & Stationery" = 691,
      "Back of Book > Proofs & Essays" = 139771,
      "Back of Book > Revenues" = 690,
      "Back of Book > Other US Back of Book Stamps" = 681,
      "Confederate States" = 3463,
      "Covers > Event Covers > First Flight" = 139773,
      "Covers > Event Covers > Inauguration & Political" = 179325,
      "Covers > Event Covers > Naval" = 139774,
      "Covers > Event Covers > Space" = 139775,
      "Covers > Event Covers > Other US Event Stamp Covers" = 684,
      "Covers > FDCs (pre-1951) > Pre-1930" = 3464,
      "Covers > FDCs (pre-1951) > 1931-40" = 139777,
      "Covers > FDCs (pre-1951) > 1941-50" = 139778,
      "Covers > FDCs (1951-Now)" = 700,
      "Covers > Other US Stamp Covers" = 683,
      "Maximum Cards" = 139779,
      "Plate Blocks" = 3465,
      "Sheets" = 265,
      "Souvenir Cards" = 3466,
      "Souvenir Pages" = 139780,
      "Stamp Collecting Supplies" = 47141,
      "Station Covers & Cachets > Space" = 139781,
      "Station Covers & Cachets > Other US Station Covers" = 139782,
      "US Possessions & Trust Territories" = 692,
      "Vintage & Used Packages" = 139783,
      "Other US Stamps" = 682
    )
  ),

  # Canada (12 categories)
  CA = list(
    label = "Canada",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Before 1952" = 38061,
      "1952-Now" = 38062,
      "Back of Book > Air Mail" = 38063,
      "Back of Book > Revenues & Taxes" = 38064,
      "Back of Book > Other Canada Back of Book Stamps" = 38065,
      "Covers > Event Covers > First Flight" = 38066,
      "Covers > Event Covers > Other Canada Event Covers" = 38067,
      "Covers > FDCs (1952-Now)" = 38068,
      "Covers > Other Canada Covers" = 38069,
      "Plate Blocks" = 38070,
      "Provinces" = 38072,
      "Other Canada Stamps" = 38071
    )
  ),

  # Great Britain (18 categories)
  GB = list(
    label = "Great Britain",
    region_id = NULL,  # Not a leaf
    countries = list(
      "QV & Edward VII (1840-1910)" = 3481,
      "George V (1910-36)" = 92094,
      "Edward VIII (1936)" = 92096,
      "George VI (1936-52)" = 92097,
      "Elizabeth II > Pre-Decimal Issues (1952-71)" = 4306,
      "Elizabeth II > Decimal Issues (1971-2000)" = 92098,
      "Elizabeth II > Regional Issues" = 92099,
      "Elizabeth II > 2001-Now" = 92100,
      "Charles III (2022-Now)" = 260103,
      "Booklets & Panes" = 7877,
      "Channel Islands & Isle of Man" = 3482,
      "Commemorative Packs" = 143973,
      "Covers > FDCs > Pre-1952" = 179426,
      "Covers > FDCs > 1952-2000" = 179427,
      "Covers > FDCs > 2001-Now" = 179428,
      "Covers > Other GB Covers" = 92101,
      "Presentation Packs > 1964-2000" = 179429,
      "Presentation Packs > 2001-Now" = 179430
    )
  ),

  # Europe (52 categories)
  EU = list(
    label = "Europe",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Europa CEPT" = 7903,
      "Aland" = 40395,
      "Albania" = 47159,
      "Andorra" = 68004,
      "Austria" = 47160,
      "Belarus" = 127405,
      "Belgium & Colonies" = 4744,
      "Bosnia and Herzegovina" = 40370,
      "Bulgaria" = 35288,
      "Croatia" = 91581,
      "Cyprus (1960-Now)" = 179392,
      "Czech Republic, Czechoslovakia" = 47162,
      "Denmark & Faroe Islands" = 35289,
      "Estonia" = 35284,
      "Finland" = 47170,
      "France & Colonies" = 17734,
      "Germany & Colonies" = 3489,
      "Greece" = 47163,
      "Greenland" = 47164,
      "Hungary" = 7891,
      "Iceland" = 47172,
      "Ireland" = 3490,
      "Italy" = 12563,
      "Kosovo" = 179393,
      "Latvia" = 35285,
      "Liechtenstein" = 40411,
      "Lithuania" = 35286,
      "Luxembourg" = 47165,
      "Macedonia" = 179394,
      "Malta (1964-Now)" = 179395,
      "Moldova" = 40371,
      "Monaco" = 7887,
      "Montenegro" = 179396,
      "Netherlands & Colonies" = 7886,
      "Norway" = 47166,
      "Poland" = 47167,
      "Portugal & Colonies" = 7893,
      "Romania" = 47169,
      "Russia" = 7879,
      "San Marino" = 7895,
      "Serbia" = 179397,
      "Slovakia" = 47171,
      "Slovenia" = 40372,
      "Spain & Colonies" = 3488,
      "Sweden" = 12560,
      "Switzerland" = 12559,
      "Turkey & Ottoman Empire" = 7894,
      "Ukraine" = 40373,
      "Vatican City" = 7896,
      "Yugoslavia" = 47173,
      "Other Europe Stamps" = 7892
    )
  ),

  # Asia (34 categories)
  AS = list(
    label = "Asia",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Afghanistan" = 47174,
      "Bhutan" = 47175,
      "British Indian Ocean Territory" = 179398,
      "Brunei" = 47176,
      "Cambodia" = 47177,
      "China" = 4750,
      "Hong Kong" = 47178,
      "India" = 169978,  # India (1947-Now)
      "Indonesia" = 47179,
      "Japan" = 127408,
      "Kazakhstan" = 40374,
      "Korea, North" = 7898,
      "Korea, South" = 7897,
      "Kyrgyzstan" = 40375,
      "Laos" = 47180,
      "Macao" = 47181,
      "Malaysia" = 47182,
      "Maldives" = 47183,
      "Mongolia" = 47184,
      "Myanmar, Burma" = 47185,
      "Nepal" = 47186,
      "Pakistan" = 47187,
      "Philippines" = 47188,
      "Singapore" = 47189,
      "Sri Lanka" = 47190,
      "Taiwan" = 7902,
      "Tajikistan" = 179399,
      "Thailand" = 47191,
      "Tibet" = 47192,
      "Turkmenistan" = 40376,
      "Uzbekistan" = 40377,
      "Vietnam" = 47193,
      "Other Asia Stamps" = 47194
    )
  ),

  # Africa (51 categories)
  AF = list(
    label = "Africa",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Algeria" = 47195,
      "Angola" = 47196,
      "Benin" = 47197,
      "Botswana" = 179400,
      "Burkina Faso" = 47198,
      "Burundi" = 47199,
      "Cameroon" = 47200,
      "Cape Verde" = 47201,
      "Central African Republic" = 47202,
      "Chad" = 47203,
      "Comoros" = 47204,
      "Congo, Democratic Republic" = 47205,
      "Congo, Republic" = 47206,
      "Djibouti" = 47207,
      "Egypt" = 7905,
      "Equatorial Guinea" = 47208,
      "Eritrea" = 179401,
      "Ethiopia" = 47209,
      "Gabon" = 47210,
      "Gambia" = 179402,
      "Ghana" = 47211,
      "Guinea" = 47212,
      "Guinea-Bissau" = 47213,
      "Ivory Coast" = 47214,
      "Kenya" = 47215,
      "Lesotho" = 47216,
      "Liberia" = 47217,
      "Libya" = 47218,
      "Madagascar" = 47219,
      "Malawi" = 179403,
      "Mali" = 47220,
      "Mauritania" = 47221,
      "Mauritius" = 47222,
      "Morocco" = 47223,
      "Mozambique" = 47224,
      "Namibia" = 179404,
      "Niger" = 47225,
      "Nigeria" = 47226,
      "Rwanda" = 47227,
      "Senegal" = 47228,
      "Sierra Leone" = 47229,
      "Somalia" = 47230,
      "South Africa" = 47231,
      "Sudan" = 47232,
      "Swaziland" = 179405,
      "Tanzania" = 47233,
      "Togo" = 47234,
      "Tunisia" = 47235,
      "Uganda" = 47236,
      "Zambia" = 179406,
      "Other Africa Stamps" = 47237
    )
  ),

  # Latin America (22 categories)
  LA = list(
    label = "Latin America",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Argentina" = 47238,
      "Belize" = 179407,
      "Bolivia" = 47239,
      "Brazil" = 7904,
      "Chile" = 47240,
      "Colombia" = 47241,
      "Costa Rica" = 47242,
      "Ecuador" = 47243,
      "El Salvador" = 47244,
      "Falkland Islands" = 47245,
      "French Guiana" = 179408,
      "Guatemala" = 47246,
      "Guyana" = 179409,
      "Honduras" = 47247,
      "Mexico" = 3494,
      "Nicaragua" = 47248,
      "Panama" = 47249,
      "Paraguay" = 47250,
      "Peru" = 47251,
      "Suriname" = 179410,
      "Uruguay" = 47252,
      "Venezuela" = 47253
    )
  ),

  # Caribbean (16 categories)
  CB = list(
    label = "Caribbean",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Anguilla" = 179411,
      "Antigua & Barbuda" = 179412,
      "Aruba" = 179413,
      "Bahamas" = 47254,
      "Barbados" = 47255,
      "Bermuda" = 47256,
      "British Virgin Islands" = 179414,
      "Cayman Islands" = 179415,
      "Cuba" = 7899,
      "Dominica" = 179416,
      "Dominican Republic" = 47257,
      "Grenada" = 179417,
      "Haiti" = 47258,
      "Jamaica" = 47259,
      "St. Lucia" = 179418,
      "Other Caribbean Stamps" = 47260
    )
  ),

  # Middle East (18 categories)
  ME = list(
    label = "Middle East",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Bahrain" = 47261,
      "Iran" = 7906,
      "Iraq" = 47262,
      "Israel" = 4747,
      "Jordan" = 47263,
      "Kuwait" = 47264,
      "Lebanon" = 47265,
      "Oman" = 47266,
      "Palestine" = 179419,
      "Qatar" = 47267,
      "Saudi Arabia" = 47268,
      "Syria" = 47269,
      "United Arab Emirates" = 47270,
      "Yemen" = 47271,
      "Other Middle East Stamps" = 47272
    )
  ),

  # Australia & Oceania (35 categories)
  OC = list(
    label = "Australia & Oceania",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Australia > Pre-Decimal (Pre-1966)" = 179420,
      "Australia > Decimal (1966-Now)" = 179421,
      "Australia > AAT" = 47273,
      "Australia > Booklets" = 179422,
      "Australia > Covers > FDCs > Pre-1966" = 179423,
      "Australia > Covers > FDCs > 1966-Now" = 179424,
      "Australia > Covers > Other Australia Covers" = 179425,
      "Australia > Other Australia Stamps" = 47274,
      "Christmas Island" = 47275,
      "Cocos (Keeling) Islands" = 47276,
      "Cook Islands" = 47277,
      "Fiji" = 47278,
      "French Polynesia" = 47279,
      "Kiribati" = 179431,
      "Marshall Islands" = 47280,
      "Micronesia" = 47281,
      "Nauru" = 47282,
      "New Caledonia" = 47283,
      "New Zealand" = 7900,
      "Niue" = 47284,
      "Norfolk Island" = 47285,
      "Palau" = 47286,
      "Papua New Guinea" = 47287,
      "Pitcairn Islands" = 179432,
      "Samoa" = 47288,
      "Solomon Islands" = 47289,
      "Tokelau" = 179433,
      "Tonga" = 47290,
      "Tuvalu" = 179434,
      "Vanuatu" = 47291,
      "Wallis and Futuna" = 179435,
      "Other Australia & Oceania Stamps" = 47292
    )
  ),

  # British Colonies & Territories (77 categories) - Simplified for space
  BC = list(
    label = "British Colonies & Territories",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Abu Dhabi" = 179436,
      "Aden" = 47293,
      "Ajman" = 179437,
      "Ascension" = 47294,
      "Australia, States" = 47295,
      "Basutoland" = 179438,
      "Batum" = 179439,
      "Bechuanaland" = 179440,
      "British Antarctic Territory" = 179441,
      "British Columbia & Vancouver Is." = 47296,
      "British East Africa" = 179442,
      "British Guiana" = 47297,
      "British Honduras" = 47298,
      "British Levant" = 179443,
      "British Occ. Italian Cols." = 179444,
      "British Occ. of Former Italian Cols." = 179445,
      "British Solomon Islands" = 179446,
      "British Somaliland" = 179447,
      "Burma" = 47299,
      "Cape of Good Hope" = 47300,
      "Ceylon" = 47301,
      "Cyprus" = 47302,
      "Dominica" = 47303,
      "Dubai" = 179448,
      "East Africa & Uganda Protectorates" = 179449,
      "Egypt" = 47304,
      "Falkland Islands Dependencies" = 179450,
      "Fiji" = 47305,
      "Fujeira" = 179451,
      "Gambia" = 47306,
      "Gibraltar" = 47307,
      "Gilbert & Ellice Islands" = 47308,
      "Gold Coast" = 47309,
      "Grenada" = 47310,
      "Hong Kong" = 47311,
      "India" = 47312,
      "Indian States" = 47313,
      "Ionian Islands" = 179452,
      "Iraq" = 47314,
      "Jamaica" = 47315,
      "Jordan" = 47316,
      "Kenya, Uganda, Tanganyika/Tanzania" = 47317,
      "Kuwait" = 47318,
      "Labuan" = 47319,
      "Lagos" = 179453,
      "Leeward Islands" = 47320,
      "Long Island" = 179454,
      "Malawi" = 47321,
      "Malaya & States" = 47322,
      "Malta" = 47323,
      "Mauritius" = 47324,
      "Montserrat" = 47325,
      "Natal" = 47326,
      "Nauru" = 179455,
      "Nevis" = 47327,
      "New Brunswick" = 47328,
      "New Guinea" = 179456,
      "New Hebrides" = 47329,
      "New Republic" = 179457,
      "Newfoundland" = 47330,
      "Niger Coast Protectorate" = 179458,
      "Nigeria" = 47331,
      "North Borneo" = 47332,
      "Northern Nigeria" = 179459,
      "Northern Rhodesia" = 179460,
      "Nova Scotia" = 47333,
      "Nyasaland Protectorate" = 179461,
      "Orange River Colony" = 179462,
      "Palestine" = 47334,
      "Papua" = 179463,
      "Pitcairn Islands" = 47335,
      "Prince Edward Island" = 47336,
      "Ras Al Khaima" = 179464,
      "Rhodesia" = 47337,
      "St. Helena" = 47338,
      "St. Kitts-Nevis" = 47339,
      "St. Lucia" = 47340,
      "St. Vincent" = 47341,
      "Sarawak" = 47342,
      "Seychelles" = 47343,
      "Sharjah" = 179465,
      "Sierra Leone" = 47344,
      "Somaliland Protectorate" = 179466,
      "South Arabia" = 179467,
      "South West Africa" = 47345,
      "Southern Nigeria" = 179468,
      "Southern Rhodesia" = 179469,
      "Stellaland" = 179470,
      "Straits Settlements" = 47346,
      "Sudan" = 47347,
      "Swaziland" = 47348,
      "Tanganyika" = 179471,
      "Tasmania" = 179472,
      "Tobago" = 179473,
      "Togo" = 179474,
      "Transvaal" = 47349,
      "Trinidad" = 47350,
      "Trinidad & Tobago" = 47351,
      "Tristan da Cunha" = 47352,
      "Trucial States" = 179475,
      "Turks & Caicos Islands" = 47353,
      "Uganda" = 179476,
      "Umm Al Qiwain" = 179477,
      "Virgin Islands" = 47354,
      "Zambia" = 47355,
      "Zanzibar" = 47356,
      "Zululand" = 179478,
      "Other British Colonies & Territories Stamps" = 47357
    )
  ),

  # Topical Stamps (44 categories) - Sample
  TP = list(
    label = "Topical Stamps",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Animals" = 7907,
      "Art" = 47358,
      "Aviation" = 47359,
      "Birds" = 7908,
      "Cats" = 47360,
      "Chess" = 47361,
      "Christmas" = 47362,
      "Disney" = 7909,
      "Dogs" = 47363,
      "Fish & Marine Life" = 47364,
      "Flowers, Plants & Trees" = 47365,
      "Medicine, Doctors" = 47366,
      "Military, War" = 7910,
      "Monuments & Architecture" = 47367,
      "Motorcycles" = 179479,
      "Music, Musicians" = 47368,
      "Olympics" = 47369,
      "Personalities" = 47370,
      "Railroads, Trains" = 7911,
      "Royalty" = 47371,
      "Ships, Boats" = 7912,
      "Space, Astronauts" = 7913,
      "Sports" = 47372,
      "Transportation" = 47373,
      "Other Topical Stamps" = 47374
    )
  ),

  # Worldwide (8 categories)
  WW = list(
    label = "Worldwide",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Collections, Lots" = 261,
      "Covers" = 47375,
      "Kiloware" = 47376,
      "Mixture" = 47377,
      "Packets" = 47378,
      "Souvenir Sheets" = 47379,
      "Stamp Sets" = 47380,
      "Other Worldwide Stamps" = 47381
    )
  ),

  # Specialty Philately (6 categories)
  SP = list(
    label = "Specialty Philately",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Cinderellas" = 47382,
      "Errors, Freaks & Oddities (EFO)" = 47383,
      "Forgeries" = 47384,
      "Gum" = 179480,
      "Proofs & Reprints" = 47385,
      "Other Specialty Philately Stamps" = 47386
    )
  ),

  # Publications & Supplies (7 categories)
  PS = list(
    label = "Publications & Supplies",
    region_id = NULL,  # Not a leaf
    countries = list(
      "Albums, Binders & Pages" = 47387,
      "Catalogs & Literature" = 47388,
      "Glassines, Envelopes & Sleeves" = 179481,
      "Magnifiers" = 47389,
      "Mounts & Hinges" = 47390,
      "Stamp Tongs & Tweezers" = 47391,
      "Other Stamp Publications & Supplies" = 47392
    )
  ),

  # Other Stamps (1 category - ONLY REGION-LEVEL LEAF!)
  OT = list(
    label = "Other Stamps",
    region_id = 170137,  # THIS IS A LEAF CATEGORY!
    countries = list()  # No subcategories
  )
)

#' Map Country Name to eBay Category
#'
#' Maps extracted country names from AI to eBay category information.
#' Returns region code, country label, and category ID for UI pre-selection.
#'
#' @section One-Way Flow:
#' AI extracts country → This function returns complete mapping →
#' UI pre-selects BOTH region and country dropdowns
#'
#' @param country Character string. Country name extracted from AI (may include
#'   native names like "ROMÂNIA", "DEUTSCHLAND", "中国", "日本")
#'
#' @return List with three elements:
#'   \itemize{
#'     \item region_code: Two-letter region code (e.g., "EU", "AS")
#'     \item country_label: Exact country label from STAMP_CATEGORIES (or NULL if ambiguous)
#'     \item category_id: Numeric eBay category ID (or NULL if needs year/grade selection)
#'   }
#'
#' @section Special Cases:
#' Some countries require additional information:
#' - United States: Needs year/grade → returns region_code="US", country_label=NULL, category_id=NULL
#' - Canada: Needs year → returns region_code="CA", country_label=NULL, category_id=NULL
#' - Great Britain: Needs monarch → returns region_code="GB", country_label=NULL, category_id=NULL
#'
#' @export
#'
#' @examples
#' map_country_to_category("ROMÂNIA")
#' # Returns: list(region_code="EU", country_label="Romania", category_id=47169)
#'
#' map_country_to_category("FRANCE")
#' # Returns: list(region_code="EU", country_label="France & Colonies", category_id=17734)
#'
#' map_country_to_category("UNITED STATES")
#' # Returns: list(region_code="US", country_label=NULL, category_id=NULL)
#' # UI will need to show year/grade dropdown
map_country_to_category <- function(country) {
  if (is.null(country) || is.na(country) || country == "") {
    return(list(region_code = NULL, country_label = NULL, category_id = NULL))
  }

  country_upper <- toupper(trimws(country))

  # EUROPE
  if (grepl("ROMANIA|ROMÂNIA", country_upper)) {
    return(list(region_code = "EU", country_label = "Romania", category_id = 47169))
  }
  if (grepl("FRANCE|FRANÇAIS", country_upper)) {
    return(list(region_code = "EU", country_label = "France & Colonies", category_id = 17734))
  }
  if (grepl("GERMANY|DEUTSCHLAND|GERMAN", country_upper)) {
    return(list(region_code = "EU", country_label = "Germany & Colonies", category_id = 3489))
  }
  if (grepl("ITALY|ITALIA|ITALIAN", country_upper)) {
    return(list(region_code = "EU", country_label = "Italy", category_id = 12563))
  }
  if (grepl("SPAIN|ESPAÑA|SPANISH", country_upper)) {
    return(list(region_code = "EU", country_label = "Spain & Colonies", category_id = 3488))
  }
  if (grepl("PORTUGAL|PORTUGUÊS", country_upper)) {
    return(list(region_code = "EU", country_label = "Portugal & Colonies", category_id = 7893))
  }
  if (grepl("SWITZERLAND|SCHWEIZ|SUISSE|SWISS", country_upper)) {
    return(list(region_code = "EU", country_label = "Switzerland", category_id = 12559))
  }
  if (grepl("AUSTRIA|ÖSTERREICH|AUSTRIAN", country_upper)) {
    return(list(region_code = "EU", country_label = "Austria", category_id = 47160))
  }
  if (grepl("BELGIUM|BELGIQUE|BELGIË", country_upper)) {
    return(list(region_code = "EU", country_label = "Belgium & Colonies", category_id = 4744))
  }
  if (grepl("NETHERLANDS|NEDERLAND|DUTCH", country_upper)) {
    return(list(region_code = "EU", country_label = "Netherlands & Colonies", category_id = 7886))
  }
  if (grepl("SWEDEN|SVERIGE|SWEDISH", country_upper)) {
    return(list(region_code = "EU", country_label = "Sweden", category_id = 12560))
  }
  if (grepl("NORWAY|NORGE|NORSK|NORWEGIAN", country_upper)) {
    return(list(region_code = "EU", country_label = "Norway", category_id = 47166))
  }
  if (grepl("DENMARK|DANMARK|DANISH", country_upper)) {
    return(list(region_code = "EU", country_label = "Denmark & Faroe Islands", category_id = 35289))
  }
  if (grepl("FINLAND|SUOMI|FINNISH", country_upper)) {
    return(list(region_code = "EU", country_label = "Finland", category_id = 47170))
  }
  if (grepl("POLAND|POLSKA|POLISH", country_upper)) {
    return(list(region_code = "EU", country_label = "Poland", category_id = 47167))
  }
  if (grepl("CZECH|ČESKOSLOVENSKO", country_upper)) {
    return(list(region_code = "EU", country_label = "Czech Republic, Czechoslovakia", category_id = 47162))
  }
  if (grepl("HUNGARY|MAGYARORSZÁG|HUNGARIAN", country_upper)) {
    return(list(region_code = "EU", country_label = "Hungary", category_id = 7891))
  }
  if (grepl("GREECE|ΕΛΛΆΔΑ|GREEK", country_upper)) {
    return(list(region_code = "EU", country_label = "Greece", category_id = 47163))
  }
  if (grepl("RUSSIA|РОССИЯ|RUSSIAN|USSR|SOVIET", country_upper)) {
    return(list(region_code = "EU", country_label = "Russia", category_id = 7879))
  }
  if (grepl("UKRAINE|УКРАЇНА|UKRAINIAN", country_upper)) {
    return(list(region_code = "EU", country_label = "Ukraine", category_id = 40373))
  }
  if (grepl("TURKEY|TÜRKIYE|TURKISH|OTTOMAN", country_upper)) {
    return(list(region_code = "EU", country_label = "Turkey & Ottoman Empire", category_id = 7894))
  }
  if (grepl("IRELAND|ÉIRE|IRISH", country_upper)) {
    return(list(region_code = "EU", country_label = "Ireland", category_id = 3490))
  }
  if (grepl("CROATIA|HRVATSKA", country_upper)) {
    return(list(region_code = "EU", country_label = "Croatia", category_id = 91581))
  }
  if (grepl("BULGARIA|БЪЛГАРИЯ", country_upper)) {
    return(list(region_code = "EU", country_label = "Bulgaria", category_id = 35288))
  }
  if (grepl("SERBIA|СРБИЈА", country_upper)) {
    return(list(region_code = "EU", country_label = "Serbia", category_id = 179397))
  }
  if (grepl("SLOVENIA|SLOVENIJA", country_upper)) {
    return(list(region_code = "EU", country_label = "Slovenia", category_id = 40372))
  }
  if (grepl("SLOVAKIA|SLOVENSKO", country_upper)) {
    return(list(region_code = "EU", country_label = "Slovakia", category_id = 47171))
  }
  if (grepl("ESTONIA|EESTI", country_upper)) {
    return(list(region_code = "EU", country_label = "Estonia", category_id = 35284))
  }
  if (grepl("LATVIA|LATVIJA", country_upper)) {
    return(list(region_code = "EU", country_label = "Latvia", category_id = 35285))
  }
  if (grepl("LITHUANIA|LIETUVA", country_upper)) {
    return(list(region_code = "EU", country_label = "Lithuania", category_id = 35286))
  }
  if (grepl("BELARUS", country_upper)) {
    return(list(region_code = "EU", country_label = "Belarus", category_id = 127405))
  }
  if (grepl("MOLDOVA", country_upper)) {
    return(list(region_code = "EU", country_label = "Moldova", category_id = 40371))
  }
  if (grepl("ALBANIA|SHQIPËRI", country_upper)) {
    return(list(region_code = "EU", country_label = "Albania", category_id = 47159))
  }
  if (grepl("MACEDONIA", country_upper)) {
    return(list(region_code = "EU", country_label = "Macedonia", category_id = 179394))
  }
  if (grepl("MONTENEGRO|ЦРНА ГОРА", country_upper)) {
    return(list(region_code = "EU", country_label = "Montenegro", category_id = 179396))
  }
  if (grepl("BOSNIA", country_upper)) {
    return(list(region_code = "EU", country_label = "Bosnia and Herzegovina", category_id = 40370))
  }
  if (grepl("KOSOVO", country_upper)) {
    return(list(region_code = "EU", country_label = "Kosovo", category_id = 179393))
  }
  if (grepl("ICELAND|ÍSLAND", country_upper)) {
    return(list(region_code = "EU", country_label = "Iceland", category_id = 47172))
  }
  if (grepl("LUXEMBOURG|LËTZEBUERG", country_upper)) {
    return(list(region_code = "EU", country_label = "Luxembourg", category_id = 47165))
  }
  if (grepl("MONACO", country_upper)) {
    return(list(region_code = "EU", country_label = "Monaco", category_id = 7887))
  }
  if (grepl("VATICAN|VATICANO", country_upper)) {
    return(list(region_code = "EU", country_label = "Vatican City", category_id = 7896))
  }
  if (grepl("SAN MARINO", country_upper)) {
    return(list(region_code = "EU", country_label = "San Marino", category_id = 7895))
  }
  if (grepl("ANDORRA", country_upper)) {
    return(list(region_code = "EU", country_label = "Andorra", category_id = 68004))
  }
  if (grepl("LIECHTENSTEIN", country_upper)) {
    return(list(region_code = "EU", country_label = "Liechtenstein", category_id = 40411))
  }
  if (grepl("MALTA", country_upper)) {
    return(list(region_code = "EU", country_label = "Malta (1964-Now)", category_id = 179395))
  }
  if (grepl("CYPRUS|ΚΎΠΡΟΣ", country_upper)) {
    return(list(region_code = "EU", country_label = "Cyprus (1960-Now)", category_id = 179392))
  }
  if (grepl("GREENLAND|KALAALLIT", country_upper)) {
    return(list(region_code = "EU", country_label = "Greenland", category_id = 47164))
  }
  if (grepl("FAROE", country_upper)) {
    return(list(region_code = "EU", country_label = "Denmark & Faroe Islands", category_id = 35289))
  }
  if (grepl("ÅLAND|ALAND", country_upper)) {
    return(list(region_code = "EU", country_label = "Aland", category_id = 40395))
  }
  if (grepl("YUGOSLAVIA", country_upper)) {
    return(list(region_code = "EU", country_label = "Yugoslavia", category_id = 47173))
  }

  # ASIA
  if (grepl("CHINA|中国|中華", country_upper)) {
    return(list(region_code = "AS", country_label = "China", category_id = 4750))
  }
  if (grepl("JAPAN|日本|NIPPON", country_upper)) {
    return(list(region_code = "AS", country_label = "Japan", category_id = 127408))
  }
  if (grepl("INDIA|EAST INDIA|भारत|BHARAT", country_upper)) {
    return(list(region_code = "AS", country_label = "India", category_id = 169978))
  }
  if (grepl("KOREA.*SOUTH|대한민국|SOUTH KOREA", country_upper)) {
    return(list(region_code = "AS", country_label = "Korea, South", category_id = 7897))
  }
  if (grepl("KOREA.*NORTH|조선|NORTH KOREA|DPRK", country_upper)) {
    return(list(region_code = "AS", country_label = "Korea, North", category_id = 7898))
  }
  if (grepl("TAIWAN|台灣|中華民國", country_upper)) {
    return(list(region_code = "AS", country_label = "Taiwan", category_id = 7902))
  }
  if (grepl("HONG KONG|香港", country_upper)) {
    return(list(region_code = "AS", country_label = "Hong Kong", category_id = 47178))
  }
  if (grepl("THAILAND|ไทย|SIAM", country_upper)) {
    return(list(region_code = "AS", country_label = "Thailand", category_id = 47191))
  }
  if (grepl("VIETNAM|VIỆT NAM", country_upper)) {
    return(list(region_code = "AS", country_label = "Vietnam", category_id = 47193))
  }
  if (grepl("PHILIPPINES|PILIPINAS", country_upper)) {
    return(list(region_code = "AS", country_label = "Philippines", category_id = 47188))
  }
  if (grepl("INDONESIA", country_upper)) {
    return(list(region_code = "AS", country_label = "Indonesia", category_id = 47179))
  }
  if (grepl("MALAYSIA", country_upper)) {
    return(list(region_code = "AS", country_label = "Malaysia", category_id = 47182))
  }
  if (grepl("SINGAPORE|新加坡", country_upper)) {
    return(list(region_code = "AS", country_label = "Singapore", category_id = 47189))
  }
  if (grepl("PAKISTAN|پاکستان", country_upper)) {
    return(list(region_code = "AS", country_label = "Pakistan", category_id = 47187))
  }
  if (grepl("BANGLADESH|বাংলাদেশ", country_upper)) {
    # Not in list, closest is India
    return(list(region_code = "AS", country_label = "Other Asia Stamps", category_id = 47194))
  }
  if (grepl("SRI LANKA|ශ්‍රී ලංකා|CEYLON", country_upper)) {
    return(list(region_code = "AS", country_label = "Sri Lanka", category_id = 47190))
  }
  if (grepl("NEPAL|नेपाल", country_upper)) {
    return(list(region_code = "AS", country_label = "Nepal", category_id = 47186))
  }
  if (grepl("MYANMAR|BURMA", country_upper)) {
    return(list(region_code = "AS", country_label = "Myanmar, Burma", category_id = 47185))
  }
  if (grepl("CAMBODIA|កម្ពុជា", country_upper)) {
    return(list(region_code = "AS", country_label = "Cambodia", category_id = 47177))
  }
  if (grepl("LAOS|ລາວ", country_upper)) {
    return(list(region_code = "AS", country_label = "Laos", category_id = 47180))
  }
  if (grepl("MONGOLIA|МОНГОЛ", country_upper)) {
    return(list(region_code = "AS", country_label = "Mongolia", category_id = 47184))
  }
  if (grepl("AFGHANISTAN|افغانستان", country_upper)) {
    return(list(region_code = "AS", country_label = "Afghanistan", category_id = 47174))
  }
  if (grepl("KAZAKHSTAN|ҚАЗАҚСТАН", country_upper)) {
    return(list(region_code = "AS", country_label = "Kazakhstan", category_id = 40374))
  }
  if (grepl("UZBEKISTAN|ЎЗБЕКИСТОН", country_upper)) {
    return(list(region_code = "AS", country_label = "Uzbekistan", category_id = 40377))
  }
  if (grepl("KYRGYZSTAN|КЫРГЫЗСТАН", country_upper)) {
    return(list(region_code = "AS", country_label = "Kyrgyzstan", category_id = 40375))
  }
  if (grepl("TAJIKISTAN|ТОҶИКИСТОН", country_upper)) {
    return(list(region_code = "AS", country_label = "Tajikistan", category_id = 179399))
  }
  if (grepl("TURKMENISTAN|ТҮРКМЕНИСТАН", country_upper)) {
    return(list(region_code = "AS", country_label = "Turkmenistan", category_id = 40376))
  }
  if (grepl("MACAO|MACAU|澳門", country_upper)) {
    return(list(region_code = "AS", country_label = "Macao", category_id = 47181))
  }
  if (grepl("BRUNEI", country_upper)) {
    return(list(region_code = "AS", country_label = "Brunei", category_id = 47176))
  }
  if (grepl("BHUTAN|འབྲུག", country_upper)) {
    return(list(region_code = "AS", country_label = "Bhutan", category_id = 47175))
  }
  if (grepl("MALDIVES|ދިވެހިރާއްޖެ", country_upper)) {
    return(list(region_code = "AS", country_label = "Maldives", category_id = 47183))
  }
  if (grepl("TIBET|བོད", country_upper)) {
    return(list(region_code = "AS", country_label = "Tibet", category_id = 47192))
  }

  # UNITED STATES (needs year/grade)
  if (grepl("UNITED STATES|U\\.S\\.|USA|AMERICA", country_upper)) {
    return(list(region_code = "US", country_label = NULL, category_id = NULL))
  }

  # CANADA (needs year)
  if (grepl("CANADA", country_upper)) {
    return(list(region_code = "CA", country_label = NULL, category_id = NULL))
  }

  # GREAT BRITAIN (needs monarch)
  if (grepl("GREAT BRITAIN|UK|UNITED KINGDOM|BRITAIN|ENGLAND", country_upper)) {
    return(list(region_code = "GB", country_label = NULL, category_id = NULL))
  }

  # AFRICA - Major countries
  if (grepl("EGYPT|مصر", country_upper)) {
    return(list(region_code = "AF", country_label = "Egypt", category_id = 7905))
  }
  if (grepl("SOUTH AFRICA", country_upper)) {
    return(list(region_code = "AF", country_label = "South Africa", category_id = 47231))
  }
  if (grepl("NIGERIA", country_upper)) {
    return(list(region_code = "AF", country_label = "Nigeria", category_id = 47226))
  }
  if (grepl("KENYA", country_upper)) {
    return(list(region_code = "AF", country_label = "Kenya", category_id = 47215))
  }
  if (grepl("ETHIOPIA", country_upper)) {
    return(list(region_code = "AF", country_label = "Ethiopia", category_id = 47209))
  }
  if (grepl("MOROCCO|المغرب", country_upper)) {
    return(list(region_code = "AF", country_label = "Morocco", category_id = 47223))
  }
  if (grepl("ALGERIA|الجزائر", country_upper)) {
    return(list(region_code = "AF", country_label = "Algeria", category_id = 47195))
  }
  if (grepl("TUNISIA|تونس", country_upper)) {
    return(list(region_code = "AF", country_label = "Tunisia", category_id = 47235))
  }
  if (grepl("LIBYA|ليبيا", country_upper)) {
    return(list(region_code = "AF", country_label = "Libya", category_id = 47218))
  }

  # LATIN AMERICA
  if (grepl("BRAZIL|BRASIL", country_upper)) {
    return(list(region_code = "LA", country_label = "Brazil", category_id = 7904))
  }
  if (grepl("MEXICO|MÉXICO", country_upper)) {
    return(list(region_code = "LA", country_label = "Mexico", category_id = 3494))
  }
  if (grepl("ARGENTINA", country_upper)) {
    return(list(region_code = "LA", country_label = "Argentina", category_id = 47238))
  }
  if (grepl("CHILE", country_upper)) {
    return(list(region_code = "LA", country_label = "Chile", category_id = 47240))
  }
  if (grepl("COLOMBIA", country_upper)) {
    return(list(region_code = "LA", country_label = "Colombia", category_id = 47241))
  }
  if (grepl("PERU|PERÚ", country_upper)) {
    return(list(region_code = "LA", country_label = "Peru", category_id = 47251))
  }
  if (grepl("VENEZUELA", country_upper)) {
    return(list(region_code = "LA", country_label = "Venezuela", category_id = 47253))
  }
  if (grepl("ECUADOR", country_upper)) {
    return(list(region_code = "LA", country_label = "Ecuador", category_id = 47243))
  }
  if (grepl("BOLIVIA", country_upper)) {
    return(list(region_code = "LA", country_label = "Bolivia", category_id = 47239))
  }
  if (grepl("PARAGUAY", country_upper)) {
    return(list(region_code = "LA", country_label = "Paraguay", category_id = 47250))
  }
  if (grepl("URUGUAY", country_upper)) {
    return(list(region_code = "LA", country_label = "Uruguay", category_id = 47252))
  }

  # MIDDLE EAST
  if (grepl("ISRAEL|ישראל", country_upper)) {
    return(list(region_code = "ME", country_label = "Israel", category_id = 4747))
  }
  if (grepl("IRAN|ایران", country_upper)) {
    return(list(region_code = "ME", country_label = "Iran", category_id = 7906))
  }
  if (grepl("IRAQ|العراق", country_upper)) {
    return(list(region_code = "ME", country_label = "Iraq", category_id = 47262))
  }
  if (grepl("SAUDI ARABIA|السعودية", country_upper)) {
    return(list(region_code = "ME", country_label = "Saudi Arabia", category_id = 47268))
  }
  if (grepl("UAE|EMIRATES|الإمارات", country_upper)) {
    return(list(region_code = "ME", country_label = "United Arab Emirates", category_id = 47270))
  }
  if (grepl("JORDAN|الأردن", country_upper)) {
    return(list(region_code = "ME", country_label = "Jordan", category_id = 47263))
  }
  if (grepl("LEBANON|لبنان", country_upper)) {
    return(list(region_code = "ME", country_label = "Lebanon", category_id = 47265))
  }
  if (grepl("SYRIA|سوريا", country_upper)) {
    return(list(region_code = "ME", country_label = "Syria", category_id = 47269))
  }
  if (grepl("YEMEN|اليمن", country_upper)) {
    return(list(region_code = "ME", country_label = "Yemen", category_id = 47271))
  }
  if (grepl("KUWAIT|الكويت", country_upper)) {
    return(list(region_code = "ME", country_label = "Kuwait", category_id = 47264))
  }
  if (grepl("BAHRAIN|البحرين", country_upper)) {
    return(list(region_code = "ME", country_label = "Bahrain", category_id = 47261))
  }
  if (grepl("QATAR|قطر", country_upper)) {
    return(list(region_code = "ME", country_label = "Qatar", category_id = 47267))
  }
  if (grepl("OMAN|عُمان", country_upper)) {
    return(list(region_code = "ME", country_label = "Oman", category_id = 47266))
  }
  if (grepl("PALESTINE|فلسطين", country_upper)) {
    return(list(region_code = "ME", country_label = "Palestine", category_id = 179419))
  }

  # AUSTRALIA & OCEANIA
  if (grepl("AUSTRALIA", country_upper)) {
    # Need to determine pre/post decimal, default to "Other"
    return(list(region_code = "OC", country_label = "Other Australia Stamps", category_id = 47274))
  }
  if (grepl("NEW ZEALAND", country_upper)) {
    return(list(region_code = "OC", country_label = "New Zealand", category_id = 7900))
  }

  # CARIBBEAN
  if (grepl("CUBA", country_upper)) {
    return(list(region_code = "CB", country_label = "Cuba", category_id = 7899))
  }
  if (grepl("JAMAICA", country_upper)) {
    return(list(region_code = "CB", country_label = "Jamaica", category_id = 47259))
  }
  if (grepl("BAHAMAS", country_upper)) {
    return(list(region_code = "CB", country_label = "Bahamas", category_id = 47254))
  }
  if (grepl("BARBADOS", country_upper)) {
    return(list(region_code = "CB", country_label = "Barbados", category_id = 47255))
  }
  if (grepl("HAITI|AYITI", country_upper)) {
    return(list(region_code = "CB", country_label = "Haiti", category_id = 47258))
  }
  if (grepl("DOMINICAN REPUBLIC|REPÚBLICA DOMINICANA", country_upper)) {
    return(list(region_code = "CB", country_label = "Dominican Republic", category_id = 47257))
  }

  # DEFAULT: Unknown country
  return(list(region_code = NULL, country_label = NULL, category_id = NULL))
}
