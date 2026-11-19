/**
 * 8.2 "What he can tell": each marvel of the dream is furniture of the study, borrowed (Meraviglia,
 * the book of impressions). Nothing comes back from the dream; the dream took these from home.
 * Pure data so it can be tested.
 */
const HOME_OBJECTS: Readonly<Record<string, string>> = {
  'THE GREAT SHIPS': 'A TOY SHIP ON THE SHELF',
  'THE HORSE TRANSPORTS': 'A WOODEN HORSE',
  'THE GALLEYS': 'A PAPER BOAT',
  'THE FLEET LEAVING VENICE': 'A LITTLE FLAG ON THE DESK',
  'THE GREAT WALLS': 'A ROW OF BOOKS LIKE TOWERS',
  'THE CITY OF ROOFS': 'A PILE OF CUSHIONS',
  'THE GOLDEN DOMES': 'THE LAMPSHADE (IT IS A DOME)',
  "THE PALACE OF THE LION'S MOUTH": 'A SHINY BISCUIT TIN',
  'THE CARVED COLUMN': 'THE CHAIR LEG, WITH HIS TOOTH MARKS ON IT',
  'THE BRONZE HERCULES': "THE PROFESSOR'S BOOKENDS",
  'A LAMP IN A COURTYARD': 'THE DESK LAMP',
  'THE GREAT CHURCH': 'AN UPTURNED GOLDEN BOWL',
  'THE HIPPODROME': 'THE RUG (IT IS A RACETRACK)',
  'AN EMPTY PEDESTAL': 'AN EMPTY SPOT ON THE SHELF',
};

export function homeObject(marvel: string): string {
  return HOME_OBJECTS[marvel] ?? `A SOUVENIR OF ${marvel.replace(/^THE /, '')}`;
}

/** Every marvel name the campaign can award (for validation). */
export const KNOWN_MARVELS: readonly string[] = Object.keys(HOME_OBJECTS);
