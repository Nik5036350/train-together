import SwiftUI

// The custom icon family (§8), ported from frontend/src/components/Icon.jsx:
// thick strokes of one weight, square caps, miter joins, circles and
// rectangles. Paths use the SVG coordinates and scale to the frame.

enum IconName: String, CaseIterable {
    case check, checkBig, pencil, chevronRight, chevronLeft, chevronDown, clock, plus
    case `repeat`, swap, skip, mode, arrowRight, arrowDown, arrowUp, trend, dots, grip
}

struct Icon: View {
    let name: IconName
    var size: CGFloat = 14

    init(_ name: IconName, size: CGFloat = 14) {
        self.name = name
        self.size = size
    }

    var body: some View {
        let box = name.viewBox
        Canvas { context, canvasSize in
            let scale = canvasSize.width / box.width
            context.scaleBy(x: scale, y: scale)
            for part in name.parts {
                switch part {
                case .stroke(let path, let width):
                    context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: width, lineCap: .square, lineJoin: .miter))
                case .fill(let path):
                    context.fill(path, with: .foreground)
                }
            }
        }
        .frame(width: size, height: size * box.height / box.width)
        .accessibilityHidden(true)
    }
}

private enum IconPart {
    case stroke(Path, CGFloat)
    case fill(Path)
}

private func poly(_ points: [(CGFloat, CGFloat)], closed: Bool = false) -> Path {
    var p = Path()
    p.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
    if closed { p.closeSubpath() }
    return p
}

private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
    Path(CGRect(x: x, y: y, width: w, height: h))
}

private extension IconName {
    var viewBox: CGSize {
        switch self {
        case .check: CGSize(width: 13, height: 13)
        case .checkBig: CGSize(width: 22, height: 22)
        case .pencil, .clock, .plus, .skip, .arrowDown, .arrowUp: CGSize(width: 14, height: 14)
        case .chevronRight: CGSize(width: 8, height: 14)
        case .chevronLeft: CGSize(width: 9, height: 16)
        case .chevronDown: CGSize(width: 11, height: 7)
        case .repeat: CGSize(width: 17, height: 17)
        case .swap: CGSize(width: 15, height: 13)
        case .mode, .arrowRight: CGSize(width: 15, height: 14)
        case .trend: CGSize(width: 14, height: 12)
        case .dots: CGSize(width: 18, height: 4)
        case .grip: CGSize(width: 10, height: 14)
        }
    }

    var parts: [IconPart] {
        switch self {
        case .check:
            [.stroke(poly([(2, 6.6), (5, 9.6), (11, 3)]), 2)]
        case .checkBig:
            [.stroke(poly([(4.5, 11.2), (9, 15.7), (17.5, 6.2)]), 2.6)]
        case .pencil:
            [
                .stroke(poly([(9.6, 2.2), (11.8, 4.4), (4.8, 11.4), (2.6, 11.4), (2.6, 9.2)], closed: true), 1.7),
                .stroke(poly([(8, 3.8), (10.2, 6)]), 1.7),
            ]
        case .chevronRight:
            [.stroke(poly([(1.6, 1.2), (6.6, 7), (1.6, 12.8)]), 2)]
        case .chevronLeft:
            [.stroke(poly([(7.2, 1.2), (2.2, 8), (7.2, 14.8)]), 2)]
        case .chevronDown:
            [.stroke(poly([(1.2, 1.6), (5.5, 5.6), (9.8, 1.6)]), 2)]
        case .clock:
            [
                .stroke(Path(ellipseIn: CGRect(x: 1.6, y: 1.6, width: 10.8, height: 10.8)), 1.8),
                .stroke(poly([(7, 3.6), (7, 7), (10, 7)]), 1.8),
            ]
        case .plus:
            [.stroke(poly([(7, 1.4), (7, 12.6)]), 2.2), .stroke(poly([(1.4, 7), (12.6, 7)]), 2.2)]
        case .repeat:
            [
                // Circle arc from the right side round to the upper right, like the SVG arc.
                .stroke(Path { p in
                    p.addArc(center: CGPoint(x: 8.5, y: 8.5), radius: 6.1, startAngle: .degrees(0),
                             endAngle: .degrees(-45), clockwise: false)
                }, 2),
                .stroke(poly([(14.8, 1.4), (14.8, 5), (11.2, 5)]), 2),
            ]
        case .swap:
            [
                .stroke(poly([(1.5, 3.8), (11.5, 3.8)]), 1.9),
                .stroke(poly([(8.6, 1.2), (11.5, 3.8), (8.6, 6.4)]), 1.9),
                .stroke(poly([(13.5, 9.2), (3.5, 9.2)]), 1.9),
                .stroke(poly([(6.4, 6.6), (3.5, 9.2), (6.4, 11.8)]), 1.9),
            ]
        case .skip:
            [.fill(poly([(2.6, 2.4), (9, 7), (2.6, 11.6)], closed: true)), .stroke(poly([(11.4, 2.4), (11.4, 11.6)]), 2)]
        case .mode:
            [
                .stroke(poly([(1.5, 4.5), (13.5, 4.5)]), 1.8),
                .stroke(poly([(1.5, 9.5), (13.5, 9.5)]), 1.8),
                .fill(rect(3, 2.6, 3.8, 3.8)),
                .fill(rect(8.2, 7.6, 3.8, 3.8)),
            ]
        case .arrowRight:
            [.stroke(poly([(1.4, 7), (12.4, 7)]), 2), .stroke(poly([(8.4, 3), (12.4, 7), (8.4, 11)]), 2)]
        case .arrowDown:
            [.stroke(poly([(7, 1.4), (7, 11.8)]), 2), .stroke(poly([(2.8, 7.6), (7, 11.8), (11.2, 7.6)]), 2)]
        case .arrowUp:
            [.stroke(poly([(7, 12.6), (7, 2.2)]), 2), .stroke(poly([(2.8, 6.4), (7, 2.2), (11.2, 6.4)]), 2)]
        case .trend:
            [.fill(rect(0.6, 7, 3, 4.4)), .fill(rect(5.5, 4, 3, 7.4)), .fill(rect(10.4, 0.8, 3, 10.6))]
        case .dots:
            [.fill(rect(0, 0, 3.6, 3.6)), .fill(rect(7.2, 0, 3.6, 3.6)), .fill(rect(14.4, 0, 3.6, 3.6))]
        case .grip:
            [1.4, 5.8, 10.2].flatMap { y in [IconPart.fill(rect(1.6, y, 2.4, 2.4)), .fill(rect(6, y, 2.4, 2.4))] }
        }
    }
}
