# Dictionary for MENA region analysis
# Categories: Southern Neighbourhood (SN), Gulf States (GS), Middle East (ME), North Africa (NA)

dictionary_mena <- list(
  sn = c(
    # Countries (IT/EN)
    "Marocco", "Morocco", "Algeria", "Tunisia", "Libia", "Libya", "Egitto", "Egypt", 
    "Israele", "Israel", "Palestina", "Palestine", "Giordania", "Jordan", "Libano", "Lebanon", "Siria", "Syria",
    # Cities
    "Rabat", "Casablanca", "Algeri", "Algiers", "Tunisi", "Tunis", "Tripoli", "Bengasi", "Benghazi", 
    "Il Cairo", "Cairo", "Damasco", "Damascus", "Aleppo", "Beirut", "Amman", "Gerusalemme", "Jerusalem", 
    "Tel Aviv", "West Bank", "Cisgiordania", "Gaza", "Ramallah",
    # Institutions & Agreements
    "Union for the Mediterranean", "UfM", "Unione per il Mediterraneo", "UpM", "Barcelona Process", 
    "Processo di Barcellona", "Euro-Mediterranean Partnership", "EMP", "EMPA", "Agadir Agreement", 
    "Accordo di Agadir", "Oslo Accords", "Accordi di Oslo", "EUBAM",
    # Political Terms
    "Southern Neighbourhood", "Southern Neighborhood", "Vicinato meridionale", "Southern neighbours", 
    "Southern neighbors", "Euro-Mediterranean", "Euromediterraneo", "Mediterranean", "Mediterraneo",
    # Local Entities
    "Polisario", "SADR", "RASD", "FLN", "Ennahda", "Haftar", "Muslim Brotherhood", "Fratelli Musulmani", 
    "Hezbollah", "Hamas", "Fatah", "PLO", "OLP"
  ),
  
  gs = c(
    # Countries (IT/EN)
    "Arabia Saudita", "Saudi Arabia", "Emirati Arabi Uniti", "United Arab Emirates", "UAE", 
    "Qatar", "Kuwait", "Bahrain", "Oman", "Yemen",
    # Cities
    "Riyadh", "Jeddah", "Abu Dhabi", "Dubai", "Doha", "Kuwait City", "Manama", "Sanaa", "Aden",
    # Institutions
    "Gulf Cooperation Council", "GCC", "Consiglio di cooperazione del Golfo", "OPEC",
    # Geo/Political
    "Gulf region", "Regione del Golfo", "Gulf states", "Stati del Golfo", "Persian Gulf", 
    "Golfo Persico", "Arabian Gulf", "Golfo Arabico", "Strait of Hormuz", "Stretto di Hormuz", "Bab el-Mandeb",
    # Specifics
    "Mohammed bin Salman", "MbS", "Khashoggi", "Aramco", "Vision 2030", "Houthi", "Ansar Allah", 
    "Al-Jazeera", "Pearl Roundabout"
  ),
  
  me = c(
    # Countries (Overlap)
    "Egitto", "Egypt", "Siria", "Syria", "Libano", "Lebanon", "Giordania", "Jordan", 
    "Israele", "Israel", "Palestina", "Palestine", "Arabia Saudita", "Saudi Arabia", 
    "UAE", "Qatar", "Kuwait", "Bahrain", "Oman", "Yemen",
    # Regional Terms
    "Middle East", "Medio Oriente", "Near East", "Vicino Oriente", "Levant", "Levante", 
    "Mashreq", "Arab world", "Mondo arabo", "Arab countries", "Paesi arabi", "Arab states",
    # Conflicts & Processes
    "Arab-Israeli conflict", "Conflitto arabo-israeliano", "Israeli-Palestinian conflict", 
    "Conflitto israelo-palestinese", "Two-state solution", "Soluzione a due stati", 
    "Peace process", "Processo di pace", "Abraham Accords", "Accordi di Abramo", 
    "Arab Spring", "Primavera araba", "Arab uprisings",
    # Groups & Crisis
    "ISIS", "ISIL", "Daesh", "Stato Islamico", "Syria Democratic Forces", "SDF", 
    "Kurdish People’s Protection Units", "YPG", "IDF", "Iron Dome",
    # Religion/Culture
    "Organization of Islamic Cooperation", "OIC", "Organizzazione della cooperazione islamica", 
    "Arab League", "Lega Araba"
  ),
  
  na = c(
    # Countries
    "Marocco", "Morocco", "Algeria", "Tunisia", "Libia", "Libya", "Egitto", "Egypt",
    # Regional Terms
    "Maghreb", "North Africa", "Nord Africa", "MENA", "SWANA",
    # Organizations
    "Arab Maghreb Union", "AMU", "UMA", "Unione del Maghreb Arabo",
    # Geography
    "Western Sahara", "Sahara occidentale", "Sahrawi", "Sahel", "Sahara", 
    "Strait of Gibraltar", "Stretto di Gibilterra", "Suez Canal", "Canale di Suez",
    # Specifics
    "Hirak", "Jasmine Revolution", "Rivoluzione dei gelsomini", "Cyrenaica", 
    "Cirenaica", "Tripolitania"
  )
)
