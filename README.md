# TUNNEL VISION — A Retro Arcade Survival Game
By Madiha Fatima, Angad Tendulkar, Kush Malwatkar, Likith Kandukuri, and Yuki Ye

Built for: Hack-A-Damien, hosted by IEEE @UAlbany

Built using: godot • gdscript • python • opencv • flask • html • javascript • mediapipe • zed

Devpost: https://devpost.com/software/tunnel-vision-vg2oce/joins/5XmvBn0JPUs_yzGQW19whQ

Tutorial: https://www.youtube.com/watch?v=EenkjmymkLM

## Inspiration

UAlbany's underground tunnel system is eerie, claustrophobic, and perfect for a chase scene. We asked ourselves: *what if you were the villain?*

In **TUNNEL VISION**, you play as a sentient blob fleeing through the tunnels beneath UAlbany's Uptown Campus — hunted by the campus's beloved superhero, **UAlbany Man**. Inspired by the concept of parasitic possession and the thrill of role reversal, we built a retro arcade runner where survival means stealing bodies, leaving slime trails, and never looking back.

## How It Works

**TUNNEL VISION** is a three-lane endless runner controlled entirely by **hand gestures** — no keyboard, no controller.

- **Swipe left or right** with your hand to switch lanes
- **Clench your fist** to possess a nearby character, draining them to keep yourself alive. A character is available to possess if they have a green and black diamond near their avatar.

Each possessed character has unique stats. Choose wisely:

| Character | Speed | Health | Ability |
|-----------|-------|--------|---------|
| **Blob** | Inherits | Inherits | Can possess others |
| **Civilian** | Medium | Medium | Baseline stats |
| **Athlete** | Fast | Low | Quick escapes |
| **Grandma** | Slow | High | Tanks hits |

When you leave a host, you drop a **puddle of slime** that slows UAlbany Man down. Your health constantly drains so it's possess or perish.

**You don't win.** You survive. One second alive = one point. The game ends when your health hits zero or UAlbany Man catches you.

## The Aesthetic

Everything is built with a **retro pixel-art style** and driven by **chiptune arcade music** — think classic 8-bit games meet campus horror. The tunnel environment, character sprites, and UI are all hand-drawn with a lo-fi, nostalgic feel.

## How We Built It

**Stack:** Godot (GDScript) · Python · Flask · OpenCV · MediaPipe · WebSockets · JavaScript

**The Hand-Tracking Pipeline:**
We used OpenCV and MediaPipe to detect and track the player's hand via webcam. Finger positions are sampled over time to calculate swipe direction and speed. Gesture events are sent from Python to Godot over WebSockets in real time, with Flask managing the data stream. Threading and async code keep the experience smooth and responsive.

**Team Breakdown:**
Our five-person team split responsibilities across game development (GDScript), original pixel art, OpenCV hand-tracking integration, and project design/management — then stitched it all together through iterative testing and bug-fixing.

## Challenges

- **Bridging OpenCV and Godot** was our biggest technical hurdle — getting real-time hand gesture data into the game engine reliably took a ton of debugging. Since none of our team members were familiar with Godot, it became a huge learning gap to navigate.
- **Scope vs. reality:** We had ambitious 3D plans, gem collection mechanics, leveling systems, and character stat screens. Time and skill constraints forced us to cut features and pivot from 3D to 2D — but the constraints pushed us toward a tighter, more focused game.
- **Keeping it "one input"** while making the game genuinely fun required constant playtesting and rebalancing.

## What We Learned

- Constraints breed creativity — the one-input rule and our skill limitations led to a better game than our original grand vision.
- Scope management is everything at a hackathon. Know your team, play to strengths, and cut ruthlessly.
- Godot is powerful and approachable, even for a team learning it on the fly.

## What's Next

TUNNEL VISION has a lot of room to grow:

- **Multiplayer mode** using multi-hand OpenCV tracking
- **Full-body controls** with head tracking for a workout-style experience
- **More characters**, levels, collectible gems, and terrain variations
- **3D upgrade** of the tunnel environment
- Visual indicator showing which character you're currently possessing and description of player statistics
