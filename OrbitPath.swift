//
//  OrbitPath.swift
//  japanShopping
//

import UIKit

/// 啟動動畫的飛機航線。
///
/// 軌跡線的 `strokeEnd` 與飛機的位置都取自這一條曲線，兩者不會各算各的而對不齊。
/// 座標以舞台邊長為 1，(0, 0) 是左上角，換算成實際點數時才乘上舞台大小。
struct OrbitPath {

    struct Curve {
        let control1: CGPoint
        let control2: CGPoint
        let end: CGPoint
    }

    /// 照 App icon 的構圖：從右側出發，順時針繞地球一圈（下半圈被收據、金幣與地球擋住），
    /// 從地球左側繞到背後，再從地球正面拉出尾跡，停在右上角。
    static let splash = OrbitPath(
        start: CGPoint(x: 0.868, y: 0.385),
        curves: [
            // 右下露出的一段環
            Curve(control1: CGPoint(x: 0.895, y: 0.430), control2: CGPoint(x: 0.820, y: 0.520), end: CGPoint(x: 0.720, y: 0.555)),
            // 下半圈，藏在地球、收據、金幣後面
            Curve(control1: CGPoint(x: 0.550, y: 0.615), control2: CGPoint(x: 0.370, y: 0.595), end: CGPoint(x: 0.220, y: 0.525)),
            // 左側露出的一段環，繞到地球左緣
            Curve(control1: CGPoint(x: 0.070, y: 0.455), control2: CGPoint(x: 0.170, y: 0.420), end: CGPoint(x: 0.265, y: 0.370)),
            // 地球背後
            Curve(control1: CGPoint(x: 0.385, y: 0.307), control2: CGPoint(x: 0.518, y: 0.418), end: CGPoint(x: 0.630, y: 0.375)),
            // 地球正面拉出的尾跡，終點是飛機停下的位置
            Curve(control1: CGPoint(x: 0.686, y: 0.354), control2: CGPoint(x: 0.762, y: 0.333), end: CGPoint(x: 0.815, y: 0.305)),
        ],
        frontCurveIndex: 4
    )

    let start: CGPoint
    let curves: [Curve]
    /// 從這一段開始，軌跡線畫在地球前方（icon 上的尾跡是疊在地球正面的）。
    let frontCurveIndex: Int

    // MARK: - Geometry

    func bezierPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: scaled(start, in: rect))
        for curve in curves {
            path.addCurve(
                to: scaled(curve.end, in: rect),
                controlPoint1: scaled(curve.control1, in: rect),
                controlPoint2: scaled(curve.control2, in: rect)
            )
        }
        return path
    }

    /// 飛機停下的位置。
    func endPoint(in rect: CGRect) -> CGPoint {
        scaled(curves.last?.end ?? start, in: rect)
    }

    /// 終點的切線角度，飛機停下時機頭朝這個方向。
    func endHeading(in rect: CGRect) -> CGFloat {
        guard let last = curves.last else { return 0 }
        let from = scaled(last.control2, in: rect)
        let to = scaled(last.end, in: rect)
        return atan2(to.y - from.y, to.x - from.x)
    }

    /// 前方軌跡開始的位置，以航線全長的比例表示。
    func frontLengthFraction(in rect: CGRect) -> CGFloat {
        let samples = sampled(in: rect)
        guard let total = samples.last?.length, total > 0 else { return 1 }
        let behindLength = samples.last { $0.curveIndex < frontCurveIndex }?.length ?? 0
        return behindLength / total
    }

    /// 飛機完全離開圓形（地球）的位置，以航線全長的比例表示。
    /// `center` 是以舞台邊長為 1 的座標，`radius` 是實際點數。
    ///
    /// 軌跡線的 `strokeEnd` 與 paced 的位置動畫都是依長度前進，
    /// 所以這個比例可以直接當成動畫進度，用來決定何時把飛機換到地球前方。
    func lengthFraction(leaving center: CGPoint, radius: CGFloat, in rect: CGRect) -> CGFloat {
        let center = scaled(center, in: rect)
        let samples = sampled(in: rect)
        guard let total = samples.last?.length, total > 0 else { return 0 }
        let lastInside = samples.last { hypot($0.point.x - center.x, $0.point.y - center.y) < radius }
        return (lastInside?.length ?? 0) / total
    }

    // MARK: - Private

    private enum Constants {
        static let samplesPerCurve = 120
    }

    private struct Sample {
        let point: CGPoint
        /// 從起點到這裡的長度。
        let length: CGFloat
        let curveIndex: Int
    }

    private func sampled(in rect: CGRect) -> [Sample] {
        var previous = scaled(start, in: rect)
        var length: CGFloat = 0
        var samples = [Sample(point: previous, length: 0, curveIndex: -1)]
        var curveStart = start

        for (index, curve) in curves.enumerated() {
            for step in 1...Constants.samplesPerCurve {
                let t = CGFloat(step) / CGFloat(Constants.samplesPerCurve)
                let current = scaled(point(on: curve, from: curveStart, at: t), in: rect)
                length += hypot(current.x - previous.x, current.y - previous.y)
                samples.append(Sample(point: current, length: length, curveIndex: index))
                previous = current
            }
            curveStart = curve.end
        }
        return samples
    }

    private func point(on curve: Curve, from start: CGPoint, at t: CGFloat) -> CGPoint {
        let u = 1 - t
        let a = u * u * u
        let b = 3 * u * u * t
        let c = 3 * u * t * t
        let d = t * t * t
        return CGPoint(
            x: a * start.x + b * curve.control1.x + c * curve.control2.x + d * curve.end.x,
            y: a * start.y + b * curve.control1.y + c * curve.control2.y + d * curve.end.y
        )
    }

    private func scaled(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
    }
}
