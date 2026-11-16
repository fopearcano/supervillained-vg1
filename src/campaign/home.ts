/**
 * 8.2 "Relics for the parish": each marvel found in the dream becomes an object at home
 * (Meraviglia system). Pure data so it can be tested.
 */
const HOME_OBJECTS: Readonly<Record<string, string>> = {
  'THE DROMONS': 'A TOY SHIP ON THE SHELF',
  'THE HORSE TRANSPORTS': 'A WOODEN HORSE',
  'THE GALLEYS': 'A PAPER BOAT',
  'THE COLUMNS OF SAN MARCO': 'TWO CANDLESTICKS',
  'THE FOUNTAIN OF VENICE': 'THE WATER BOWL, POLISHED',
  'THE FLEET LEAVING VENICE': 'A LITTLE FLAG ON THE DESK',
  'THE HERMIT ORATORY': 'A WHITEWASHED PEBBLE',
  'THE HERMIT GARDEN': 'A DRIED FIG',
  'THE TWO SKELETONS': 'TWO CHEW BONES, SIDE BY SIDE',
  'THE GREAT WALLS': 'A ROW OF BOOKS LIKE TOWERS',
  'THE CITY OF ROOFS': 'A PILE OF CUSHIONS',
  'THE GOLDEN DOMES': 'AN UPTURNED GOLDEN BOWL',
  'THE GOLDEN PALACE': 'A SHINY BISCUIT TIN',
  'THE CHAPEL OF RELICS': 'A SHOEBOX OF TREASURES',
  'THE CHURCH OF THE APOSTLES': 'A POSTCARD OF A CHURCH',
  'THE GREAT CHURCH': 'THE LAMPSHADE (IT IS A DOME)',
  'THE HIPPODROME': 'THE RUG (IT IS A RACETRACK)',
  'THE STATUES': "THE PROFESSOR'S BOOKENDS",
};

export function homeObject(marvel: string): string {
  return HOME_OBJECTS[marvel] ?? `A SOUVENIR OF ${marvel.replace(/^THE /, '')}`;
}

/** Every marvel name the campaign can award (for validation). */
export const KNOWN_MARVELS: readonly string[] = Object.keys(HOME_OBJECTS);
