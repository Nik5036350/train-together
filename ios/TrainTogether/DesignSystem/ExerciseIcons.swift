import SwiftUI
import TrainTogetherCore

// Exercise pictograms (§8), in the style of the brand figures: a round head,
// a thick torso bar, limbs of one weight with square caps, equipment in
// rectangles and plates. Coordinates are on a 24-point grid; side views show
// a barbell end-on as a plate. (First generated from a design sketch; edit
// the coordinates here.)

/// An exercise's pictogram, drawn in the foreground style.
struct ExerciseGlyph: View {
    let icon: ExerciseIcon
    var size: CGFloat = 24

    var body: some View {
        Canvas { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 24, y: canvasSize.height / 24)
            for part in icon.parts {
                switch part {
                case .stroke(let points, let width):
                    var path = Path()
                    path.addLines(points)
                    // Thin equipment lines end flat; body parts get square caps.
                    let cap: CGLineCap = width >= limbWidth ? .square : .butt
                    context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: .miter, miterLimit: 4))
                case .fill(let path):
                    context.fill(path, with: .foreground, style: FillStyle(eoFill: true))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The pictogram on an ink square: how exercises appear in lists. On dark
/// surfaces the square is paper instead.
struct ExerciseTile: View {
    let icon: ExerciseIcon
    let onDark: Bool
    @ScaledMetric private var size: CGFloat

    init(_ icon: ExerciseIcon, size: CGFloat = 36, onDark: Bool = false) {
        self.icon = icon
        self.onDark = onDark
        _size = ScaledMetric(wrappedValue: size, relativeTo: .headline)
    }

    var body: some View {
        ExerciseGlyph(icon: icon, size: size * 0.74)
            .foregroundStyle(onDark ? Palette.ink : Palette.paper)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 4).fill(onDark ? Palette.paper : Palette.ink))
            .accessibilityHidden(true)
    }
}

enum GlyphPart {
    case stroke([CGPoint], CGFloat)
    case fill(Path)
}

private let headRadius: CGFloat = 2.4
private let torsoWidth: CGFloat = 4
private let limbWidth: CGFloat = 2.6
private let barWidth: CGFloat = 1.5

private func points(_ list: [(CGFloat, CGFloat)]) -> [CGPoint] { list.map { CGPoint(x: $0.0, y: $0.1) } }

private func head(_ x: CGFloat, _ y: CGFloat) -> GlyphPart { disc(x, y, headRadius) }
private func torso(_ list: (CGFloat, CGFloat)...) -> GlyphPart { .stroke(points(list), torsoWidth) }
private func limb(_ list: (CGFloat, CGFloat)...) -> GlyphPart { .stroke(points(list), limbWidth) }
private func bar(_ list: (CGFloat, CGFloat)..., width: CGFloat = barWidth) -> GlyphPart { .stroke(points(list), width) }
private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> GlyphPart { .fill(Path(CGRect(x: x, y: y, width: w, height: h))) }

private func disc(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> GlyphPart {
    .fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)))
}

/// A weight plate seen face-on: a disc with a hole.
private func plate(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, hole: CGFloat = 0.9) -> GlyphPart {
    var path = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    path.addEllipse(in: CGRect(x: x - hole, y: y - hole, width: 2 * hole, height: 2 * hole))
    return .fill(path)
}

/// A barbell seen from the front, a big and a small plate on each side.
private func barbell(y: CGFloat) -> [GlyphPart] {
    [bar((1.2, y), (22.8, y)),
     rect(2.5, y - 3.2, 1.7, 6.4), rect(1.3, y - 2.1, 1.1, 4.2),
     rect(19.8, y - 3.2, 1.7, 6.4), rect(21.6, y - 2.1, 1.1, 4.2)]
}

/// A small dumbbell held upright.
private func dumbbell(_ x: CGFloat, _ y: CGFloat) -> [GlyphPart] {
    [bar((x, y - 2.3), (x, y + 2.3), width: 1.3), rect(x - 1.5, y - 2.9, 3, 1.5), rect(x - 1.5, y + 1.4, 3, 1.5)]
}

private func kettlebell(_ x: CGFloat, _ y: CGFloat) -> [GlyphPart] {
    [disc(x, y, 2.1), bar((x - 1.2, y - 1.8), (x - 1.2, y - 3.5), (x + 1.2, y - 3.5), (x + 1.2, y - 1.8), width: 1.2)]
}

/// A figure standing face-on, arms left to the caller.
private func standing(headY: CGFloat) -> [GlyphPart] {
    [head(12, headY), torso((12, headY + 3.8), (12, headY + 10.6)),
     limb((10.9, headY + 10.4), (10.1, 21.7)), limb((13.1, headY + 10.4), (13.9, 21.7))]
}

extension ExerciseIcon {
    var parts: [GlyphPart] {
        switch self {
        case .benchPress:
            [rect(3.0, 15.8, 13.0, 1.8), rect(4.4, 17.6, 1.6, 4.4), rect(12.8, 17.6, 1.6, 4.4),
                head(4.4, 13.3), torso((7.2, 13.9), (14.2, 13.9)), limb((14.0, 14.0), (18.6, 12.6), (19.8, 21.7)),
                limb((9.0, 12.4), (9.0, 6.6)), plate(9.0, 4.4, 3.8, hole: 1.0)]
        case .fly:
            standing(headY: 3.8) + [limb((10.4, 8.6), (4.2, 12.2)), limb((13.6, 8.6), (19.8, 12.2)),
                rect(0.6, 0.6, 2.6, 2.6), rect(20.8, 0.6, 2.6, 2.6),
                bar((4.2, 12.2), (1.9, 3.0), width: 1.0), bar((19.8, 12.2), (22.1, 3.0), width: 1.0), rect(3.0, 11.0, 2.4, 2.4), rect(18.6, 11.0, 2.4, 2.4)]
        case .pushUp:
            [bar((1.8, 19.8), (22.2, 19.8), width: 1.2),
                head(4.8, 10.4), torso((7.6, 12.2), (14.4, 14.6)), limb((14.0, 14.6), (21.4, 17.8)),
                limb((8.6, 12.8), (8.6, 18.6))]
        case .dip:
            [bar((5.6, 11.6), (5.6, 22.4), width: 1.6), bar((18.4, 11.6), (18.4, 22.4), width: 1.6),
                bar((3.8, 11.6), (7.2, 11.6), width: 1.8), bar((16.8, 11.6), (20.2, 11.6), width: 1.8),
                head(12, 3.4), torso((12, 7.0), (12, 13.6)),
                limb((10.4, 7.8), (6.4, 11.0)), limb((13.6, 7.8), (17.6, 11.0)),
                limb((10.9, 13.4), (10.5, 19.4)), limb((13.1, 13.4), (13.5, 19.4))]
        case .deadlift:
            [head(7.0, 6.6), torso((9.4, 9.2), (15.0, 12.6)), limb((15.0, 12.6), (13.4, 17.0), (15.0, 21.7)),
                limb((10.0, 10.2), (10.4, 16.2)), plate(10.4, 18.6, 3.3)]
        case .row:
            [head(4.6, 8.4), torso((7.4, 9.6), (15.8, 11.4)), limb((15.8, 11.4), (14.0, 16.4), (15.6, 21.7)),
                limb((9.2, 10.6), (13.0, 10.8), (12.4, 13.4)), plate(12.4, 15.0, 2.9, hole: 0.9)]
        case .pulldown:
            [bar((12, 1.0), (12, 4.6), width: 1.0), bar((3.4, 5.8), (5.0, 4.6), (19.0, 4.6), (20.6, 5.8), width: 1.6),
                head(12, 7.8), torso((12, 11.2), (12, 16.6)), limb((10.4, 12.0), (6.8, 10.6), (5.8, 5.2)), limb((13.6, 12.0), (17.2, 10.6), (18.2, 5.2)),
                rect(7.4, 17.0, 9.2, 1.8), limb((10.8, 16.8), (9.4, 21.7)), limb((13.2, 16.8), (14.6, 21.7))]
        case .pullUp:
            [bar((1.8, 2.0), (22.2, 2.0), width: 1.6),
                head(12, 6.0), torso((12, 9.6), (12, 16.0)),
                limb((10.4, 10.2), (6.2, 8.2), (6.4, 2.4)), limb((13.6, 10.2), (17.8, 8.2), (17.6, 2.4)),
                limb((10.9, 15.8), (10.6, 21.4)), limb((13.1, 15.8), (13.4, 21.4))]
        case .overheadPress:
            barbell(y: 2.6) + [head(12, 5.6), torso((12, 9.2), (12, 15.4)),
                limb((10.4, 9.8), (7.6, 2.8)), limb((13.6, 9.8), (16.4, 2.8)),
                limb((10.9, 15.2), (9.8, 21.7)), limb((13.1, 15.2), (14.2, 21.7))]
        case .lateralRaise:
            standing(headY: 4.2) + [limb((10.4, 9.0), (3.4, 9.0)), limb((13.6, 9.0), (20.6, 9.0))] + dumbbell(2.6, 9.0) + dumbbell(21.4, 9.0)
        case .curl:
            [head(11.4, 3.6), torso((11.4, 7.4), (11.4, 14.2)), limb((11.2, 14.0), (10.2, 21.7)), limb((11.8, 14.0), (13.4, 21.7)),
                limb((12.6, 8.4), (13.2, 13.0), (17.2, 9.6))] + dumbbell(17.8, 9.0)
        case .pushdown:
            [rect(15.0, 0.6, 4.4, 1.6), bar((17.2, 2.2), (16.6, 13.8), width: 1.0),
                head(10.8, 3.8), torso((10.8, 7.6), (10.4, 14.2)), limb((10.2, 14.0), (9.4, 21.7)), limb((10.8, 14.0), (12.4, 21.7)),
                limb((12.0, 8.6), (12.6, 12.8), (16.6, 14.6)), bar((15.0, 14.6), (18.2, 14.6), width: 1.8)]
        case .tricepsExtension:
            [head(10.0, 5.0), torso((10.8, 8.8), (10.8, 15.2)), limb((10.6, 15.0), (9.6, 21.7)), limb((11.2, 15.0), (12.8, 21.7)),
                limb((12.0, 9.6), (12.8, 2.2), (16.6, 5.8))] + dumbbell(17.4, 6.4)
        case .squat:
            barbell(y: 7.6) + [head(12, 4.2), torso((12, 7.6), (12, 13.0)),
                limb((10.5, 8.6), (7.8, 11.0), (7.0, 7.6)), limb((13.5, 8.6), (16.2, 11.0), (17.0, 7.6)),
                limb((10.9, 12.8), (6.8, 16.4), (8.4, 21.7)), limb((13.1, 12.8), (17.2, 16.4), (15.6, 21.7))]
        case .legPress:
            [bar((1.8, 21.8), (22.2, 21.8), width: 1.4), bar((3.6, 7.8), (6.2, 20.8), width: 2.0), rect(5.6, 18.4, 5.4, 1.8),
                head(5.8, 5.2), torso((6.8, 8.6), (8.6, 16.4)), limb((8.8, 16.2), (14.2, 11.4), (18.4, 14.8)),
                bar((20.0, 7.6), (20.0, 20.8), width: 2.6)]
        case .lunge:
            [head(10.8, 3.4), torso((10.8, 7.2), (10.8, 13.4)), limb((10.8, 13.2), (16.2, 14.2), (16.4, 21.7)),
                limb((10.8, 13.2), (8.4, 19.6), (3.6, 21.4)), limb((11.4, 8.2), (12.4, 13.4))]
        case .legExtension:
            [bar((5.0, 5.6), (6.4, 14.6), width: 1.8), rect(6.4, 14.4, 7.2, 1.8), bar((10.0, 16.2), (10.0, 22.2), width: 1.6),
                head(8.6, 3.6), torso((8.8, 7.4), (8.8, 13.2)), limb((9.0, 13.2), (14.4, 13.0), (20.0, 10.2)),
                limb((9.6, 8.4), (12.6, 13.2)), rect(19.0, 8.4, 3.0, 3.0)]
        case .legCurl:
            [rect(2.4, 14.8, 14.6, 1.8), rect(4.0, 16.6, 1.6, 5.2), rect(13.8, 16.6, 1.6, 5.2),
                head(3.8, 11.4), torso((6.6, 12.8), (13.4, 12.8)), limb((13.2, 12.8), (18.6, 13.4), (17.6, 7.2)), rect(16.2, 5.2, 3.0, 2.8)]
        case .calfRaise:
            [rect(8.8, 20.0, 7.4, 2.4), head(12, 3.2), torso((12, 7.0), (12, 13.4)),
                limb((11.4, 13.2), (11.4, 18.4), (12.8, 19.6)), limb((12.6, 13.2), (12.6, 18.4), (14.0, 19.6)),
                limb((12.4, 8.0), (13.2, 13.2)),
                bar((19.6, 15.6), (19.6, 6.4), width: 2.0), bar((17.2, 8.8), (19.6, 6.4), (22.0, 8.8), width: 2.0)]
        case .hipThrust:
            [rect(1.4, 12.6, 5.6, 1.8), rect(3.2, 14.4, 1.6, 7.6),
                head(3.6, 9.6), torso((6.4, 11.4), (13.6, 11.0)), limb((13.4, 11.0), (18.4, 10.8), (18.6, 21.7)),
                plate(12.4, 7.0, 3.0)]
        case .hipAbduction:
            [head(12, 3.8), torso((12, 7.6), (12, 14.0)), rect(7.6, 14.2, 8.8, 1.8), bar((12, 16.0), (12, 22.2), width: 1.6),
                limb((10.4, 8.6), (8.4, 13.6)), limb((13.6, 8.6), (15.6, 13.6)),
                limb((10.9, 13.6), (4.6, 18.4), (4.2, 21.7)), limb((13.1, 13.6), (19.4, 18.4), (19.8, 21.7)),
                rect(1.4, 14.6, 1.8, 5.4), rect(20.8, 14.6, 1.8, 5.4)]
        case .plank:
            [bar((1.8, 20.4), (22.2, 20.4), width: 1.2), head(4.2, 11.8), torso((6.8, 13.8), (14.4, 15.4)),
                limb((14.0, 15.4), (21.6, 18.2)), limb((7.4, 14.2), (7.4, 18.6), (3.4, 18.6))]
        case .crunch:
            [bar((1.8, 20.6), (22.2, 20.6), width: 1.2), head(5.4, 10.4), torso((7.6, 13.0), (12.4, 17.6)),
                limb((12.4, 17.8), (16.6, 12.2), (20.2, 18.6)), limb((8.6, 13.4), (10.8, 10.2))]
        case .legRaise:
            [bar((3.0, 1.8), (21.0, 1.8), width: 1.6), head(11.8, 5.4), torso((9.8, 8.4), (9.8, 14.6)),
                limb((8.8, 8.8), (8.8, 2.2)), limb((9.8, 14.4), (20.6, 14.4))]
        case .carry:
            standing(headY: 3.6) + [limb((10.4, 8.4), (7.8, 14.6)), limb((13.6, 8.4), (16.2, 14.6))] + kettlebell(7.4, 17.8) + kettlebell(16.6, 17.8)
        case .swing:
            [head(10.8, 3.6), torso((11.0, 7.4), (11.0, 14.0)), limb((10.8, 13.8), (9.6, 21.7)), limb((11.4, 13.8), (13.0, 21.7)),
                limb((12.2, 8.6), (18.2, 9.2))] + kettlebell(20.2, 11.4)
        case .rower:
            [bar((1.6, 20.6), (22.4, 20.6), width: 1.4), plate(19.4, 16.8, 3.0, hole: 1.0), rect(4.8, 17.4, 4.0, 1.6),
                head(4.8, 7.4), torso((5.8, 10.8), (7.2, 16.6)), limb((7.2, 16.6), (12.0, 13.2), (15.6, 18.2)),
                limb((6.6, 11.8), (13.4, 12.6)), bar((13.4, 12.6), (18.0, 15.4), width: 1.0)]
        case .bike:
            [plate(17.4, 17.6, 3.6, hole: 1.1), bar((6.2, 9.2), (9.6, 9.2), width: 1.8), bar((8.4, 9.6), (11.4, 20.6), width: 1.6),
                bar((15.6, 7.2), (14.2, 16.4), width: 1.6), bar((5.0, 21.8), (20.8, 21.8), width: 1.6),
                head(14.6, 3.2), torso((12.4, 6.2), (8.4, 8.2)), limb((8.4, 8.2), (13.2, 12.4), (11.4, 17.6)),
                limb((12.4, 6.8), (15.8, 7.6))]
        case .run:
            [head(14.6, 3.4), torso((13.8, 7.2), (11.2, 13.2)), limb((11.4, 13.0), (15.8, 15.0), (14.6, 21.4)),
                limb((11.0, 13.2), (8.2, 17.6), (3.6, 16.4)), limb((13.2, 8.2), (16.8, 10.6), (19.0, 7.8)), limb((12.8, 8.4), (9.0, 10.6), (6.8, 8.2))]
        case .generic:
            [bar((2.4, 12), (21.6, 12), width: 2.0), rect(4.4, 7.0, 2.4, 10), rect(2.0, 8.8, 1.9, 6.4), rect(17.2, 7.0, 2.4, 10), rect(20.1, 8.8, 1.9, 6.4)]
        }
    }
}
