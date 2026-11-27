# App Store pictures

Made by `tools/store-shots.sh` from raw screenshots of the app's demo tape.

| Folder | Picture size | For |
| --- | --- | --- |
| `iphone` | 1320 x 2868 | iPhone, 6.9 inch display |
| `duo` 1 and 2 | 1398 x 2034 | Folding iPhone, cover screen |
| `duo` 3 and 4 | 2007 x 2853 | Folding iPhone, open and upright |
| `duo` 5 | 2853 x 2007 | Folding iPhone, open and sideways |

The folding iPhone sizes are the simulator's own screen sizes. Check them against the sizes App Store Connect asks for before uploading, and change the sizes in the script if they differ.

To make them again, take new raw screenshots with the names the script expects, then run `tools/store-shots.sh <folder of raw screenshots>` from the repository root. The headlines are in the script.
