import AppKit
import CoreText
// Native vector construction of the Rilova lowercase-r direction.
let p=CGMutablePath()
p.move(to:.init(x:408,y:490))
p.addCurve(to:.init(x:516,y:365),control1:.init(x:408,y:407),control2:.init(x:454,y:365))
p.addCurve(to:.init(x:599,y:430),control1:.init(x:567,y:365),control2:.init(x:599,y:387))
p.addLine(to:.init(x:599,y:524))
p.addCurve(to:.init(x:836,y:394),control1:.init(x:665,y:449),control2:.init(x:755,y:394))
p.addCurve(to:.init(x:901,y:434),control1:.init(x:874,y:394),control2:.init(x:901,y:408))
p.addCurve(to:.init(x:792,y:510),control1:.init(x:901,y:474),control2:.init(x:851,y:503))
p.addCurve(to:.init(x:629,y:576),control1:.init(x:704,y:518),control2:.init(x:662,y:535))
p.addCurve(to:.init(x:599,y:669),control1:.init(x:607,y:603),control2:.init(x:599,y:628))
p.addLine(to:.init(x:599,y:802))
p.addCurve(to:.init(x:506,y:918),control1:.init(x:599,y:880),control2:.init(x:568,y:918))
p.addCurve(to:.init(x:408,y:808),control1:.init(x:441,y:918),control2:.init(x:408,y:877));p.closeSubpath()
let d="M408 490 C408 407 454 365 516 365 C567 365 599 387 599 430 L599 524 C665 449 755 394 836 394 C874 394 901 408 901 434 C901 474 851 503 792 510 C704 518 662 535 629 576 C607 603 599 628 599 669 L599 802 C599 880 568 918 506 918 C441 918 408 877 408 808 Z"
func c(_ h:String)->CGColor { let n=Int(h,radix:16)!;return .init(red:CGFloat(n>>16&255)/255,green:CGFloat(n>>8&255)/255,blue:CGFloat(n&255)/255,alpha:1) }
let ivory=c("F6F3EB"),tide=c("072E32")
func save(_ name:String,_ w:Int,_ h:Int,alpha:Bool=false,_ draw:(CGContext)->Void){
 let x=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:(alpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue)!
 x.translateBy(x:0,y:CGFloat(h));x.scaleBy(x:1,y:-1);x.setShouldAntialias(true);draw(x)
 let b=NSBitmapImageRep(cgImage:x.makeImage()!)
 try! b.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:name))
}
func mark(_ x:CGContext,_ left:CGFloat,_ top:CGFloat,_ width:CGFloat,_ ink:CGColor){x.saveGState();x.translateBy(x:left,y:top);x.scaleBy(x:width/600,y:width/600);x.translateBy(x:-360,y:-315);x.addPath(p);x.setFillColor(ink);x.fillPath();x.restoreGState()}
func icon(_ x:CGContext,_ left:CGFloat,_ top:CGFloat,_ size:CGFloat,rounded:Bool=false){
 x.saveGState();x.translateBy(x:left,y:top);x.scaleBy(x:size/1254,y:size/1254)
 if rounded {x.addPath(CGPath(roundedRect:.init(x:0,y:0,width:1254,height:1254),cornerWidth:280,cornerHeight:280,transform:nil));x.clip()}
 let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[c("0C5257"),c("032A2E")] as CFArray,locations:[0,1])!
 x.drawLinearGradient(g,start:.init(x:1254,y:0),end:.init(x:0,y:1254),options:[.drawsBeforeStartLocation,.drawsAfterEndLocation]);x.addPath(p);x.setFillColor(ivory);x.fillPath();x.restoreGState()
}
func text(_ x:CGContext,_ s:String,_ left:CGFloat,_ baseline:CGFloat,_ size:CGFloat,_ ink:CGColor){
 let f=CTFontCreateWithName("HelveticaNeue-Medium" as CFString,size,nil)
 let a:[NSAttributedString.Key:Any]=[.init(kCTFontAttributeName as String):f,.init(kCTForegroundColorAttributeName as String):ink]
 let line=CTLineCreateWithAttributedString(NSAttributedString(string:s,attributes:a))
 x.saveGState();x.translateBy(x:left,y:baseline);x.scaleBy(x:1,y:-1);x.textPosition = .zero;CTLineDraw(line,x);x.restoreGState()
}
save("rilova-app-icon.png",1024,1024){icon($0,0,0,1024)}
for (n,ink) in [("teal",tide),("ivory",ivory)] {
 save("rilova-mark-\(n).png",1200,1300,alpha:true){mark($0,0,0,1200,ink)}
 save("rilova-logo-\(n).png",1800,500,alpha:true){x in mark(x,15,65,340,ink);text(x,"Rilova",410,278,220,ink);text(x,"Habits that fit real life.",420,370,55,ink)}
 let hex=n == "teal" ? "072E32":"F6F3EB"
 try! "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"360 315 600 650\" role=\"img\" aria-label=\"Rilova\"><path fill=\"#\(hex)\" d=\"\(d)\"/></svg>\n".write(toFile:"rilova-mark-\(n).svg",atomically:true,encoding:.utf8)
}
try! "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1254 1254\" role=\"img\" aria-label=\"Rilova app icon\"><defs><linearGradient id=\"tide\" x1=\"1\" y1=\"0\" x2=\"0\" y2=\"1\"><stop stop-color=\"#0C5257\"/><stop offset=\"1\" stop-color=\"#032A2E\"/></linearGradient></defs><path fill=\"url(#tide)\" d=\"M0 0H1254V1254H0Z\"/><path fill=\"#F6F3EB\" d=\"\(d)\"/></svg>\n".write(toFile:"rilova-app-icon.svg",atomically:true,encoding:.utf8)
save("brand-board.png",1800,1260){x in
 x.setFillColor(ivory);x.fill(.init(x:0,y:0,width:1800,height:1260))
 text(x,"RILOVA  /  BRAND IDENTITY",110,110,27,c("49706F"))
 mark(x,75,180,285,tide);text(x,"Rilova",420,340,190,tide);text(x,"Habits that fit real life.",430,432,46,c("315653"));icon(x,1310,185,340,rounded:true)
 x.setFillColor(tide);x.fill(.init(x:0,y:580,width:1800,height:450))
 mark(x,90,645,225,ivory);text(x,"Rilova",355,795,130,ivory);text(x,"Habits that fit real life.",362,875,34,ivory)
 for (i,s) in [CGFloat(128),64,40].enumerated(){icon(x,1210+CGFloat(i)*175,725,s,rounded:true)}
 text(x,"RICH TIDE",110,1120,26,tide);text(x,"Deep teal · Warm ivory · A natural upward rhythm",110,1175,30,c("315653"))
 for (i,h) in ["072E32","0C5257","0E7468","F6F3EB"].enumerated(){x.setFillColor(c(h));x.fill(.init(x:1190+CGFloat(i)*135,y:1080,width:100,height:100));text(x,h,1190+CGFloat(i)*135,1220,20,tide)}
}
print("Rendered logo pack.")
