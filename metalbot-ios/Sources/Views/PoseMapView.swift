import SwiftUI

/// A reusable 2D canvas for displaying robot trajectory and current pose.
struct PoseMapView: View {
    let poses: [PoseEntry]
    let currentPose: PoseEntry?
    let isTracking: Bool
    
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(
                x: size.width / 2 + offset.width,
                y: size.height / 2 + offset.height
            )
            
            drawGrid(context: context, size: size, center: center)
            drawAxes(context: context, size: size, center: center)
            drawPath(context: context, center: center)
            drawCurrentPose(context: context, center: center)
        }
    }
    
    // MARK: - Core Drawing Logic
    
    private func drawGrid(context: GraphicsContext, size: CGSize, center: CGPoint) {
        var path = Path()
        let step = scale // 1 meter grid interval
        
        let startX = Int(-center.x / step) - 1
        let endX = Int((size.width - center.x) / step) + 1
        let startY = Int(-center.y / step) - 1
        let endY = Int((size.height - center.y) / step) + 1
        
        for x in startX...endX {
            let px = center.x + CGFloat(x) * step
            path.move(to: CGPoint(x: px, y: 0))
            path.addLine(to: CGPoint(x: px, y: size.height))
        }
        
        for y in startY...endY {
            let py = center.y + CGFloat(y) * step
            path.move(to: CGPoint(x: 0, y: py))
            path.addLine(to: CGPoint(x: size.width, y: py))
        }
        
        context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 1)
    }
    
    private func drawAxes(context: GraphicsContext, size: CGSize, center: CGPoint) {
        let axisColor = Color.black
        let lineWidth: CGFloat = 2.0
        let arrowLen: CGFloat = 12.0
        let arrowAngle: CGFloat = .pi / 6
        
        // Z Axis (Right)
        var zAxis = Path()
        zAxis.move(to: center)
        let zEnd = CGPoint(x: size.width, y: center.y)
        zAxis.addLine(to: zEnd)
        
        zAxis.move(to: zEnd)
        zAxis.addLine(to: CGPoint(x: zEnd.x - cos(arrowAngle) * arrowLen, y: zEnd.y - sin(arrowAngle) * arrowLen))
        zAxis.move(to: zEnd)
        zAxis.addLine(to: CGPoint(x: zEnd.x - cos(arrowAngle) * arrowLen, y: zEnd.y + sin(arrowAngle) * arrowLen))
        
        context.stroke(zAxis, with: .color(axisColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        
        // X Axis (Forward = Up on Canvas)
        var xAxis = Path()
        xAxis.move(to: center)
        let xEnd = CGPoint(x: center.x, y: 0)
        xAxis.addLine(to: xEnd)
        
        xAxis.move(to: xEnd)
        xAxis.addLine(to: CGPoint(x: xEnd.x - sin(arrowAngle) * arrowLen, y: xEnd.y + cos(arrowAngle) * arrowLen))
        xAxis.move(to: xEnd)
        xAxis.addLine(to: CGPoint(x: xEnd.x + sin(arrowAngle) * arrowLen, y: xEnd.y + cos(arrowAngle) * arrowLen))
        
        context.stroke(xAxis, with: .color(axisColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
    
    private func drawPath(context: GraphicsContext, center: CGPoint) {
        guard !poses.isEmpty else {
            context.fill(Path(ellipseIn: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)), with: .color(.orange))
            return
        }
        
        let count = poses.count
        
        if isTracking || count < 2 {
            var path = Path()
            for (index, pose) in poses.enumerated() {
                let canvasX = center.x + CGFloat(pose.z) * scale
                let canvasY = center.y - CGFloat(pose.x) * scale
                let pt = CGPoint(x: canvasX, y: canvasY)
                
                if index == 0 {
                    path.move(to: pt)
                } else {
                    path.addLine(to: pt)
                }
            }
            context.stroke(path, with: .color(.cyan), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        } else {
            for i in 1..<count {
                let p1 = poses[i-1]
                let p2 = poses[i]
                
                let pt1 = CGPoint(x: center.x + CGFloat(p1.z) * scale, y: center.y - CGFloat(p1.x) * scale)
                let pt2 = CGPoint(x: center.x + CGFloat(p2.z) * scale, y: center.y - CGFloat(p2.x) * scale)
                
                var segment = Path()
                segment.move(to: pt1)
                segment.addLine(to: pt2)
                
                let fraction = Double(i) / Double(count - 1)
                context.stroke(segment, with: .color(jetColor(for: fraction)), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        
        context.fill(Path(ellipseIn: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)), with: .color(.orange))
    }
    
    private func drawCurrentPose(context: GraphicsContext, center: CGPoint) {
        guard let pose = currentPose else { return }
        
        let canvasX = center.x + CGFloat(pose.z) * scale
        let canvasY = center.y - CGFloat(pose.x) * scale
        let pt = CGPoint(x: canvasX, y: canvasY)
        
        context.fill(Path(ellipseIn: CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12)), with: .color(.green))
        
        let canvasAngle = -CGFloat.pi / 2 - CGFloat(pose.yaw)
        let arrowLen: CGFloat = 24
        let endPt = CGPoint(
            x: pt.x + cos(canvasAngle) * arrowLen,
            y: pt.y + sin(canvasAngle) * arrowLen
        )
        
        var arrowPath = Path()
        arrowPath.move(to: pt)
        arrowPath.addLine(to: endPt)
        
        let headAngle: CGFloat = .pi / 6
        let headLen: CGFloat = 10
        let p1 = CGPoint(
            x: endPt.x - cos(canvasAngle - headAngle) * headLen,
            y: endPt.y - sin(canvasAngle - headAngle) * headLen
        )
        let p2 = CGPoint(
            x: endPt.x - cos(canvasAngle + headAngle) * headLen,
            y: endPt.y - sin(canvasAngle + headAngle) * headLen
        )
        
        arrowPath.move(to: endPt)
        arrowPath.addLine(to: p1)
        arrowPath.move(to: endPt)
        arrowPath.addLine(to: p2)
        
        context.stroke(arrowPath, with: .color(.green), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
    
    private func jetColor(for t: Double) -> Color {
        let r = max(0, min(1, 1.5 - abs(4 * t - 3)))
        let g = max(0, min(1, 1.5 - abs(4 * t - 2)))
        let b = max(0, min(1, 1.5 - abs(4 * t - 1)))
        return Color(red: r, green: g, blue: b)
    }
}
