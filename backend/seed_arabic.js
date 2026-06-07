const sql = require('mssql');

const config = {
  user: 'sa', password: 'YourPassword123!', server: 'localhost', database: 'DiscoverEgypt',
  options: { encrypt: false, trustServerCertificate: true },
};

// Real Unsplash photo IDs collected for each specific Egyptian place
// Format: name_en => [img1, img2, img3]
const imgs = {
  'Pyramids of Giza':                    ['1k7JC31SRyI',              'MoonoldXeqs',              'rxv2qwYPe6s'],
  'The Great Sphinx':                    ['ggBy_3XcR7I',              'DCmxODj-RoY',              'QAPH2rhEMtU'],
  'Egyptian Museum':                     ['1528360983277-13d401cdc186','1601785358687-37c64b99d7b8','1503177119275-0aa32b3a9368'],
  'Karnak Temple':                       ['P72S-BUa1Wg',              'xU2uSbD197Y',              'gvbAvvxAGik'],
  'Luxor Temple':                        ['AOHE9sVo9-I',              'Z4_Oqh238WI',              'Kcn_6MrDFns'],
  'Valley of the Kings':                 ['5aEHOQrb2Qk',              'kDdjlhNRvug',              'TG1OTMcn5Qk'],
  'Abu Simbel Temples':                  ['BSv0T4uRWew',              'oTRD-P4nU8Q',              'GNdp2Q4VZjw'],
  'Philae Temple':                       ['ST42rwyBXAI',              '1590418606746-018840f9ded0','1601785358687-37c64b99d7b8'],
  'Khan el-Khalili Bazaar':              ['MB2eoqiNKiw',              '8HvggAV2Ddk',              '1555396273-86e4a079f9f6'],
  'Citadel of Saladin':                  ['1528360983277-13d401cdc186','1601785358687-37c64b99d7b8','1590418606746-018840f9ded0'],
  'Bibliotheca Alexandrina':             ['1570197788417-0201a48ab2cc','1544551763-46a013bb70d5', '1528360983277-13d401cdc186'],
  'White Desert':                        ['K3S4VPuswyw',              'LzVB84KkZOE',              '3j9D000gF8k'],
  'Siwa Oasis':                          ['1vBXUCb-bXQ',              'vpWV_lTAnp8',              '1547036967-3ca730fad54e'],
  'Ras Mohammed National Park':          ['56Dx8rfnGAU',              'QURU8IY-RaI',              '1544551763-46a013bb70d5'],
  'Dahab Blue Hole':                     ['QURU8IY-RaI',              'snb8JwEKZd0',              '9uN4p0og0ns'],
  'Edfu Temple':                         ['1590418606746-018840f9ded0','gvbAvvxAGik',              '1601785358687-37c64b99d7b8'],
  'Kom Ombo Temple':                     ['1601785358687-37c64b99d7b8','1590418606746-018840f9ded0','xU2uSbD197Y'],
  'Coptic Cairo':                        ['1528360983277-13d401cdc186','1601785358687-37c64b99d7b8','1590418606746-018840f9ded0'],
  'Nile Cruise Luxor to Aswan':          ['I7WdqSaNLII',              'LmqBEnyBOTM',              'XMxINoMi2Q4'],
  'St Catherine\'s Monastery':           ['Fe3eF795O24',              'RGR-7-G4Wvs',              'bvGwWNZwl3w'],
  'Saqqara Step Pyramid':                ['1503177119275-0aa32b3a9368','1568322445-bcad4a7df741', '1589816040618-4c37f8562be7'],
  'Dahshur Red Pyramid':                 ['1503177119275-0aa32b3a9368','MoonoldXeqs',              'rxv2qwYPe6s'],
  'Temple of Hatshepsut':                ['3J6zNepjJRg',              '1590418606746-018840f9ded0','1601785358687-37c64b99d7b8'],
  'Colossi of Memnon':                   ['1590418606746-018840f9ded0','gvbAvvxAGik',              '1601785358687-37c64b99d7b8'],
  'Medinet Habu Temple':                 ['1601785358687-37c64b99d7b8','1590418606746-018840f9ded0','P72S-BUa1Wg'],
  'Dendera Temple':                      ['1590418606746-018840f9ded0','1601785358687-37c64b99d7b8','xU2uSbD197Y'],
  'Abydos Temple of Seti I':             ['1601785358687-37c64b99d7b8','1590418606746-018840f9ded0','gvbAvvxAGik'],
  'Esna Temple of Khnum':                ['P72S-BUa1Wg',              '1590418606746-018840f9ded0','xU2uSbD197Y'],
  'Nubian Village Gharb Soheil':         ['1547036967-3ca730fad54e',  '1vBXUCb-bXQ',              'vpWV_lTAnp8'],
  'Memphis & Mit Rahina':                ['1503177119275-0aa32b3a9368','1528360983277-13d401cdc186','1568322445-bcad4a7df741'],
  'Qaitbay Citadel':                     ['1570197788417-0201a48ab2cc','1544551763-46a013bb70d5', '1518709268805-4e9042af9f23'],
  'Bent Pyramid Dahshur':                ['MoonoldXeqs',              '1503177119275-0aa32b3a9368','rxv2qwYPe6s'],
  'Grand Egyptian Museum (GEM)':         ['1503177119275-0aa32b3a9368','1568322445-bcad4a7df741', '1589816040618-4c37f8562be7'],
  'Nubian Museum':                       ['1547036967-3ca730fad54e',  '1590418606746-018840f9ded0','1544550285-f813152fb2fd'],
  'Luxor Museum':                        ['1601785358687-37c64b99d7b8','1590418606746-018840f9ded0','gvbAvvxAGik'],
  'National Museum of Egyptian Civilization': ['1528360983277-13d401cdc186','1601785358687-37c64b99d7b8','1590418606746-018840f9ded0'],
  'Greco-Roman Museum Alexandria':       ['1570197788417-0201a48ab2cc','1528360983277-13d401cdc186','1544551763-46a013bb70d5'],
  'Islamic Art Museum Cairo':            ['1528360983277-13d401cdc186','1601785358687-37c64b99d7b8','MB2eoqiNKiw'],
  'Alexandria National Museum':          ['1570197788417-0201a48ab2cc','1544551763-46a013bb70d5', '1528360983277-13d401cdc186'],
  'Coptic Museum':                       ['1528360983277-13d401cdc186','1601785358687-37c64b99d7b8','1590418606746-018840f9ded0'],
  'Sohag National Museum':              ['1601785358687-37c64b99d7b8','1590418606746-018840f9ded0','1528360983277-13d401cdc186'],
  'Sharm El Sheikh Museum':             ['1518709268805-4e9042af9f23','1544551763-46a013bb70d5', '56Dx8rfnGAU'],
  'Wadi El Rayan Waterfalls':           ['K3S4VPuswyw',              '1547036967-3ca730fad54e',  '1vBXUCb-bXQ'],
  'Lake Nasser':                         ['I7WdqSaNLII',              'LmqBEnyBOTM',              '1590418606746-018840f9ded0'],
  'Wadi El Gemal National Park':         ['56Dx8rfnGAU',              '1544551763-46a013bb70d5', '1518709268805-4e9042af9f23'],
  'Fayoum Oasis':                        ['1vBXUCb-bXQ',              'K3S4VPuswyw',              '1547036967-3ca730fad54e'],
  'Colored Canyon Sinai':               ['RGR-7-G4Wvs',              'Fe3eF795O24',              'K3S4VPuswyw'],
  'Wadi Degla Protectorate':            ['K3S4VPuswyw',              'LzVB84KkZOE',              '1547036967-3ca730fad54e'],
  'El Gouna Lagoons':                    ['1570197788417-0201a48ab2cc','1544551763-46a013bb70d5', '1518709268805-4e9042af9f23'],
  'Ain Sokhna Hot Springs':             ['1518709268805-4e9042af9f23','1544551763-46a013bb70d5', '1570197788417-0201a48ab2cc'],
  'Bahariya Oasis Black Desert':        ['LzVB84KkZOE',              'K3S4VPuswyw',              '3j9D000gF8k'],
  'Taba Protected Area':                 ['1518709268805-4e9042af9f23','QURU8IY-RaI',              '1544551763-46a013bb70d5'],
  'Al-Azhar Mosque':                     ['1590418606746-018840f9ded0','1601785358687-37c64b99d7b8','1528360983277-13d401cdc186'],
  'Muhammad Ali Mosque':                 ['1528360983277-13d401cdc186','1601785358687-37c64b99d7b8','1590418606746-018840f9ded0'],
  'Mosque of Ibn Tulun':                ['1601785358687-37c64b99d7b8','1528360983277-13d401cdc186','1590418606746-018840f9ded0'],
  'Ben Ezra Synagogue':                  ['1528360983277-13d401cdc186','1601785358687-37c64b99d7b8','1590418606746-018840f9ded0'],
  'Abu Mena Basilica Ruins':            ['1590418606746-018840f9ded0','1601785358687-37c64b99d7b8','gvbAvvxAGik'],
  'Hanging Church':                      ['1528360983277-13d401cdc186','1601785358687-37c64b99d7b8','1590418606746-018840f9ded0'],
  'Mosque of Amr ibn al-As':            ['1601785358687-37c64b99d7b8','1590418606746-018840f9ded0','1528360983277-13d401cdc186'],
  'Mount Sinai (Gebel Musa)':           ['NwFPqN0plSY',              'RGR-7-G4Wvs',              'bvGwWNZwl3w'],
  'Al-Hussein Mosque':                   ['1590418606746-018840f9ded0','1601785358687-37c64b99d7b8','1528360983277-13d401cdc186'],
  'Monastery of St Anthony':            ['Fe3eF795O24',              'bvGwWNZwl3w',              'RGR-7-G4Wvs'],
  'Tentmakers Bazaar (El-Khayamiya)':   ['MB2eoqiNKiw',              '8HvggAV2Ddk',              '1555396273-86e4a079f9f6'],
  'Aswan Souk':                          ['MB2eoqiNKiw',              '8HvggAV2Ddk',              '1547036967-3ca730fad54e'],
  'Luxor Souk (Central Market)':        ['8HvggAV2Ddk',              'MB2eoqiNKiw',              '1601785358687-37c64b99d7b8'],
  'City Stars Mall':                     ['1611892440929-f1a5d80cfb4b','1582719508461-04c3aac9e5c4','1551882547-ff5cf1236b3e'],
  'Alexandria Fish Market':             ['1570197788417-0201a48ab2cc','1555396273-86e4a079f9f6', '1414235077124-b188b6392b3b'],
  'Wekalet el-Balah':                   ['MB2eoqiNKiw',              '8HvggAV2Ddk',              '1555396273-86e4a079f9f6'],
  'Sharm Old Market':                    ['8HvggAV2Ddk',              'MB2eoqiNKiw',              '1518709268805-4e9042af9f23'],
  'Gold Market Sayeda Zeinab':          ['MB2eoqiNKiw',              '8HvggAV2Ddk',              '1601785358687-37c64b99d7b8'],
  'Port Said Duty-Free Zone':           ['1570197788417-0201a48ab2cc','1544551763-46a013bb70d5', '1528360983277-13d401cdc186'],
  'Sphinx Mall El-Mohandessin':         ['1611892440929-f1a5d80cfb4b','1582719508461-04c3aac9e5c4','1551882547-ff5cf1236b3e'],
  'Sharm El Sheikh Naama Bay':          ['1518709268805-4e9042af9f23','1544551763-46a013bb70d5', '56Dx8rfnGAU'],
  'Hurghada Sahl Hasheesh':             ['1570197788417-0201a48ab2cc','1518709268805-4e9042af9f23','1544551763-46a013bb70d5'],
  'Marsa Matrouh Cleopatra Beach':      ['1544551763-46a013bb70d5', '1570197788417-0201a48ab2cc','1518709268805-4e9042af9f23'],
  'Agami Beach Alexandria':             ['1570197788417-0201a48ab2cc','1544551763-46a013bb70d5', '1518709268805-4e9042af9f23'],
  'Ras Sedr Beach':                      ['1518709268805-4e9042af9f23','QURU8IY-RaI',              '1544551763-46a013bb70d5'],
  'Nuweiba Beach':                       ['1544551763-46a013bb70d5', '1570197788417-0201a48ab2cc','QURU8IY-RaI'],
  'Taba Beach':                          ['1518709268805-4e9042af9f23','1544551763-46a013bb70d5', '1570197788417-0201a48ab2cc'],
  'North Coast Sahel':                   ['1570197788417-0201a48ab2cc','1544551763-46a013bb70d5', '1518709268805-4e9042af9f23'],
  'Abu Galum Protectorate':             ['QURU8IY-RaI',              '56Dx8rfnGAU',              '1544551763-46a013bb70d5'],
  'Makadi Bay':                          ['1518709268805-4e9042af9f23','1570197788417-0201a48ab2cc','1544551763-46a013bb70d5'],
  'Felucca Sunset Cruise Aswan':        ['LmqBEnyBOTM',              'I7WdqSaNLII',              'XMxINoMi2Q4'],
  'Nile Dinner Cruise Cairo':           ['I7WdqSaNLII',              'LmqBEnyBOTM',              'XMxINoMi2Q4'],
  'Lake Nasser Cruise':                  ['I7WdqSaNLII',              'LmqBEnyBOTM',              '1590418606746-018840f9ded0'],
  'Red Sea Liveaboard Diving':          ['snb8JwEKZd0',              '9uN4p0og0ns',              'QURU8IY-RaI'],
  'Luxor Sound and Light Nile Cruise':  ['LmqBEnyBOTM',              'I7WdqSaNLII',              '1601785358687-37c64b99d7b8'],
  'Dahabiya Sailing Nile Luxor':        ['I7WdqSaNLII',              'LmqBEnyBOTM',              'XMxINoMi2Q4'],
  'Aqaba Gulf Ferry Nuweiba–Aqaba':     ['XMxINoMi2Q4',              '1570197788417-0201a48ab2cc','1544551763-46a013bb70d5'],
  'Alexandria Harbour Boat Tour':       ['1570197788417-0201a48ab2cc','XMxINoMi2Q4',              '1544551763-46a013bb70d5'],
  'Nile Houseboat Experience Cairo':    ['I7WdqSaNLII',              'XMxINoMi2Q4',              'LmqBEnyBOTM'],
  'Suez Canal Cruise Port Said':        ['XMxINoMi2Q4',              'I7WdqSaNLII',              '1570197788417-0201a48ab2cc'],
  'Great Sand Sea':                      ['LzVB84KkZOE',              '3j9D000gF8k',              'WGYGBTqfZSc'],
  'Farafra Oasis':                       ['1vBXUCb-bXQ',              'K3S4VPuswyw',              'LzVB84KkZOE'],
  'Crystal Mountain Bahariya':          ['K3S4VPuswyw',              'LzVB84KkZOE',              '3j9D000gF8k'],
  'Kharga Oasis':                        ['1vBXUCb-bXQ',              'K3S4VPuswyw',              '1547036967-3ca730fad54e'],
  'Dakhla Oasis':                        ['1547036967-3ca730fad54e',  '1vBXUCb-bXQ',              'K3S4VPuswyw'],
  'Eastern Desert Wadi Hammamat':       ['LzVB84KkZOE',              '3j9D000gF8k',              'K3S4VPuswyw'],
  'Sinai Desert Bedouin Camp':          ['RGR-7-G4Wvs',              'Fe3eF795O24',              'LzVB84KkZOE'],
  'Gilf Kebir Plateau':                  ['LzVB84KkZOE',              'WGYGBTqfZSc',              '3j9D000gF8k'],
  'Wadi El Hitan (Whale Valley)':       ['K3S4VPuswyw',              'LzVB84KkZOE',              '1547036967-3ca730fad54e'],
  'Wadi Rum-like Desert Sinai':         ['RGR-7-G4Wvs',              'LzVB84KkZOE',              'Fe3eF795O24'],
  'Koshary El Tahrir':                   ['1555396273-86e4a079f9f6', '1414235077124-b188b6392b3b','1504674900247-0877df9cc836'],
  'Abou El Sid':                         ['1504674900247-0877df9cc836','1555396273-86e4a079f9f6', '1414235077124-b188b6392b3b'],
  'Sequoia Nile Restaurant':            ['I7WdqSaNLII',              '1504674900247-0877df9cc836','1555396273-86e4a079f9f6'],
  'Felfela Restaurant Cairo':           ['1555396273-86e4a079f9f6', '1414235077124-b188b6392b3b','1504674900247-0877df9cc836'],
  'El Fishawy Café':                     ['MB2eoqiNKiw',              '1504674900247-0877df9cc836','1555396273-86e4a079f9f6'],
  'Sofra Restaurant Luxor':             ['1601785358687-37c64b99d7b8','1504674900247-0877df9cc836','1555396273-86e4a079f9f6'],
  'Panorama Restaurant Aswan':          ['I7WdqSaNLII',              '1504674900247-0877df9cc836','1555396273-86e4a079f9f6'],
  'Little Buddha Sharm':                 ['1518709268805-4e9042af9f23','1504674900247-0877df9cc836','1555396273-86e4a079f9f6'],
  'El Tarboush Alexandria':             ['1570197788417-0201a48ab2cc','1555396273-86e4a079f9f6', '1414235077124-b188b6392b3b'],
  'Naguib Mahfouz Café':                ['MB2eoqiNKiw',              '1504674900247-0877df9cc836','8HvggAV2Ddk'],
  'Karam El Sham Damascus':             ['1555396273-86e4a079f9f6', '1414235077124-b188b6392b3b','1504674900247-0877df9cc836'],
  'Halim Pizza & Pasta':                ['1414235077124-b188b6392b3b','1555396273-86e4a079f9f6', '1504674900247-0877df9cc836'],
  'Marriott Mena House Cairo':          ['1503177119275-0aa32b3a9368','1611892440929-f1a5d80cfb4b','1582719508461-04c3aac9e5c4'],
  'Four Seasons Cairo at Nile Plaza':   ['1611892440929-f1a5d80cfb4b','I7WdqSaNLII',              '1582719508461-04c3aac9e5c4'],
  'Sofitel Legend Old Cataract Aswan':  ['1611892440929-f1a5d80cfb4b','I7WdqSaNLII',              '1582719508461-04c3aac9e5c4'],
  'Winter Palace Hotel Luxor':          ['1611892440929-f1a5d80cfb4b','1601785358687-37c64b99d7b8','1582719508461-04c3aac9e5c4'],
  'Movenpick Resort Aswan':             ['1582719508461-04c3aac9e5c4','1611892440929-f1a5d80cfb4b','I7WdqSaNLII'],
  'Hilton Hurghada Plaza':              ['1611892440929-f1a5d80cfb4b','1518709268805-4e9042af9f23','1582719508461-04c3aac9e5c4'],
  'Marriott Sharm El Sheikh':           ['1611892440929-f1a5d80cfb4b','1518709268805-4e9042af9f23','1582719508461-04c3aac9e5c4'],
  'Cecil Hotel Alexandria':              ['1611892440929-f1a5d80cfb4b','1570197788417-0201a48ab2cc','1582719508461-04c3aac9e5c4'],
  'Steigenberger El Tahrir Cairo':      ['1611892440929-f1a5d80cfb4b','1528360983277-13d401cdc186','1582719508461-04c3aac9e5c4'],
  'Nubian Guesthouse Aswan':            ['1547036967-3ca730fad54e',  '1vBXUCb-bXQ',              '1611892440929-f1a5d80cfb4b'],
  'Baron Palace Hotel Heliopolis':      ['1611892440929-f1a5d80cfb4b','1582719508461-04c3aac9e5c4','1551882547-ff5cf1236b3e'],
  'Sonesta St. George Luxor':           ['1601785358687-37c64b99d7b8','1611892440929-f1a5d80cfb4b','1582719508461-04c3aac9e5c4'],
  'Zooba Street Food':                   ['1555396273-86e4a079f9f6', '1414235077124-b188b6392b3b','8HvggAV2Ddk'],
  'Sea Grill Alexandria':               ['1570197788417-0201a48ab2cc','1555396273-86e4a079f9f6', '1504674900247-0877df9cc836'],
  'Taboula Lebanese Restaurant':        ['1555396273-86e4a079f9f6', '1414235077124-b188b6392b3b','1504674900247-0877df9cc836'],
  'El Dahan Grills':                     ['1414235077124-b188b6392b3b','1555396273-86e4a079f9f6', '1504674900247-0877df9cc836'],
  'Kan Zaman Cairo':                     ['MB2eoqiNKiw',              '1504674900247-0877df9cc836','1555396273-86e4a079f9f6'],
  'Blue Blue Hurghada':                  ['1518709268805-4e9042af9f23','1504674900247-0877df9cc836','1544551763-46a013bb70d5'],
  'Aswan Moon Restaurant':              ['I7WdqSaNLII',              '1504674900247-0877df9cc836','1547036967-3ca730fad54e'],
  'La Bodega Cairo':                     ['1504674900247-0877df9cc836','1555396273-86e4a079f9f6', '1414235077124-b188b6392b3b'],
  'Sofitel Cairo El Gezirah':           ['I7WdqSaNLII',              '1611892440929-f1a5d80cfb4b','1582719508461-04c3aac9e5c4'],
  'Kempinski Nile Hotel Cairo':         ['I7WdqSaNLII',              '1611892440929-f1a5d80cfb4b','1582719508461-04c3aac9e5c4'],
  'Hyatt Regency Sharm El Sheikh':      ['1611892440929-f1a5d80cfb4b','1518709268805-4e9042af9f23','1582719508461-04c3aac9e5c4'],
  'InterContinental Hurghada':          ['1582719508461-04c3aac9e5c4','1518709268805-4e9042af9f23','1611892440929-f1a5d80cfb4b'],
  'Nefertiti Hotel Luxor':              ['1601785358687-37c64b99d7b8','1611892440929-f1a5d80cfb4b','1551882547-ff5cf1236b3e'],
  'Helnan Palestine Hotel Alexandria':  ['1570197788417-0201a48ab2cc','1611892440929-f1a5d80cfb4b','1582719508461-04c3aac9e5c4'],
  'Conrad Cairo':                        ['1611892440929-f1a5d80cfb4b','I7WdqSaNLII',              '1582719508461-04c3aac9e5c4'],
  'Basata Eco-Lodge Sinai':             ['Fe3eF795O24',              'RGR-7-G4Wvs',              '1518709268805-4e9042af9f23'],
};

// Category fallbacks for any place not in the map above
const catImgs = {
  historical: ['1601785358687-37c64b99d7b8','1590418606746-018840f9ded0','1528360983277-13d401cdc186'],
  museum:     ['1528360983277-13d401cdc186','1601785358687-37c64b99d7b8','1590418606746-018840f9ded0'],
  nature:     ['1547036967-3ca730fad54e',  '1544550285-f813152fb2fd', '1518709268805-4e9042af9f23'],
  beach:      ['1518709268805-4e9042af9f23','1544551763-46a013bb70d5', '1570197788417-0201a48ab2cc'],
  desert:     ['LzVB84KkZOE',              '3j9D000gF8k',              'K3S4VPuswyw'],
  religious:  ['1590418606746-018840f9ded0','1601785358687-37c64b99d7b8','1528360983277-13d401cdc186'],
  market:     ['MB2eoqiNKiw',              '8HvggAV2Ddk',              '1555396273-86e4a079f9f6'],
  restaurant: ['1555396273-86e4a079f9f6', '1414235077124-b188b6392b3b','1504674900247-0877df9cc836'],
  hotel:      ['1611892440929-f1a5d80cfb4b','1582719508461-04c3aac9e5c4','1551882547-ff5cf1236b3e'],
  cruise:     ['I7WdqSaNLII',              'LmqBEnyBOTM',              'XMxINoMi2Q4'],
};

function imgUrl(id) {
  // Both old (timestamp) and new (alphanumeric) Unsplash IDs work with this URL
  return `https://images.unsplash.com/photo-${id}?w=900&q=85&fit=crop`;
}

async function seed() {
  let pool;
  try {
    pool = await sql.connect(config);
    console.log('Connected');

    const rows = (await pool.request().query('SELECT id, name_en, category FROM Places ORDER BY id')).recordset;
    console.log(`Found ${rows.length} places`);

    let done = 0;
    for (const { id, name_en, category } of rows) {
      const imgIds = imgs[name_en] || catImgs[category] || catImgs.historical;

      // Replace images only (Arabic text already seeded correctly)
      const del = pool.request();
      del.input('pid', sql.Int, id);
      await del.query('DELETE FROM PlaceImages WHERE place_id=@pid');

      for (let i = 0; i < imgIds.length; i++) {
        const ins = pool.request();
        ins.input('pid', sql.Int, id);
        ins.input('url', sql.NVarChar(500), imgUrl(imgIds[i]));
        ins.input('ord', sql.Int, i + 1);
        await ins.query('INSERT INTO PlaceImages (place_id, image_url, sort_order) VALUES (@pid, @url, @ord)');
      }

      done++;
      if (done % 20 === 0) console.log(`${done}/${rows.length}...`);
    }

    console.log(`Done! Updated images for ${done} places.`);
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    if (pool) await pool.close();
  }
}

seed();
