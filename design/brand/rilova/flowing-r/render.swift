import AppKit
import CoreText
// Owner-selected flowing-R reference; strengthened upright for small sizes.
let loop = "M288 800 L288 428 C288 295 380 222 500 222 C636 222 736 316 736 435 C736 519 688 576 614 605 L578 558 C641 533 681 485 681 428 C681 343 603 277 507 278 C407 278 340 353 340 443 L326 800 C324 823 292 823 288 800 Z"
let wave = "M352 520 C419 479 458 496 507 548 C579 619 646 696 756 726 C735 766 697 794 648 790 C550 787 472 699 407 607 C379 572 368 543 352 520 Z"
func path(_ s:String)->CGPath {
 let re=try! NSRegularExpression(pattern:"[MLCZ]|-?[0-9]+(?:\\.[0-9]+)?")
 let t=re.matches(in:s,range:NSRange(s.startIndex...,in:s)).map{String(s[Range($0.range,in:s)!])}
 let p=CGMutablePath();var i=0
 func point()->CGPoint{defer{i+=2};return .init(x:Double(t[i])!,y:Double(t[i+1])!)}
 while i<t.count {let command=t[i];i+=1;switch command {
 case "M":p.move(to:point())
 case "L":p.addLine(to:point())
 case "C":let a=point(),b=point(),end=point();p.addCurve(to:end,control1:a,control2:b)
 case "Z":p.closeSubpath()
 default:fatalError("Unknown vector command")}}
 return p
}
let shapes=[path(loop),path(wave)], space=CGColorSpace(name:CGColorSpace.sRGB)!
func color(_ h:String)->CGColor {let v=Int(h,radix:16)!;return CGColor(colorSpace:space,components:[CGFloat(v>>16&255)/255,CGFloat(v>>8&255)/255,CGFloat(v&255)/255,1])!}
func png(_ name:String,_ w:Int,_ h:Int,alpha:Bool=false,_ draw:(CGContext)->Void){
 let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:(alpha ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue)!
 c.translateBy(x:0,y:CGFloat(h));c.scaleBy(x:1,y:-1);c.setShouldAntialias(true);draw(c)
 let b=NSBitmapImageRep(cgImage:c.makeImage()!);try! b.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:name))
}
func gradient(_ c:CGContext,_ colors:[String],from:CGPoint,to:CGPoint){let g=CGGradient(colorsSpace:space,colors:colors.map(color) as CFArray,locations:nil)!;c.drawLinearGradient(g,start:from,end:to,options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])}
func mark(_ c:CGContext,_ left:CGFloat=0,_ top:CGFloat=0,_ size:CGFloat=1024,_ ink:String="F9FAF0",graduated:Bool=false){
 c.saveGState();c.translateBy(x:left,y:top);c.scaleBy(x:size/1024,y:size/1024)
 for p in shapes {c.addPath(p);if graduated {c.saveGState();c.clip();gradient(c,["F9FAF0","A0D4CA"],from:.init(x:360,y:300),to:.init(x:700,y:780));c.restoreGState()}else{c.setFillColor(color(ink));c.fillPath()}}
 c.restoreGState()
}
func icon(_ c:CGContext,_ left:CGFloat=0,_ top:CGFloat=0,_ size:CGFloat=1024,dark:Bool=false,rounded:Bool=false){
 c.saveGState();c.translateBy(x:left,y:top);c.scaleBy(x:size/1024,y:size/1024)
 if rounded{c.addPath(CGPath(roundedRect:.init(x:0,y:0,width:1024,height:1024),cornerWidth:225,cornerHeight:225,transform:nil));c.clip()}
 gradient(c,dark ? ["318C90","115052","042A30"] : ["DFEBCD","86C3B6","08788E"],from:.init(x:80,y:20),to:.init(x:920,y:1024));mark(c,graduated:dark);c.restoreGState()
}
func text(_ c:CGContext,_ s:String,_ x:CGFloat,_ baseline:CGFloat,_ size:CGFloat,_ ink:String){
 let f=CTFontCreateWithName("AvenirNext-Regular" as CFString,size,nil)
 let a:[NSAttributedString.Key:Any]=[.init(kCTFontAttributeName as String):f,.init(kCTForegroundColorAttributeName as String):color(ink)]
 c.saveGState();c.translateBy(x:x,y:baseline);c.scaleBy(x:1,y:-1);c.textPosition = .zero;CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string:s,attributes:a)),c);c.restoreGState()
}
func lockup(_ c:CGContext,_ ink:String){mark(c,-55,-180,780,ink);text(c,"ilova",505,410,350,ink);text(c,"Habits that fit real life.",162,555,50,ink)}
png("rilova-app-icon.png",1024,1024){icon($0)}
png("rilova-app-icon-dark.png",1024,1024){icon($0,dark:true)}
for (n,ink) in [("teal","072E32"),("ivory","F9FAF0")]{
 png("rilova-mark-\(n).png",1024,1024,alpha:true){mark($0,0,0,1024,ink)}
 png("rilova-logo-\(n).png",1500,620,alpha:true){lockup($0,ink)}
 let body="<path fill=\"#\(ink)\" d=\"\(loop)\"/><path fill=\"#\(ink)\" d=\"\(wave)\"/>"
 try! "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1024 1024\" role=\"img\" aria-label=\"Rilova\">\(body)</svg>\n".write(toFile:"rilova-mark-\(n).svg",atomically:true,encoding:.utf8)
}
let defs="<defs><linearGradient id=\"tide\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\"><stop stop-color=\"#DFEBCD\"/><stop offset=\".5\" stop-color=\"#86C3B6\"/><stop offset=\"1\" stop-color=\"#08788E\"/></linearGradient></defs>"
try! "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1024 1024\" role=\"img\" aria-label=\"Rilova app icon\">\(defs)<path fill=\"url(#tide)\" d=\"M0 0H1024V1024H0Z\"/><path fill=\"#F9FAF0\" d=\"\(loop)\"/><path fill=\"#F9FAF0\" d=\"\(wave)\"/></svg>\n".write(toFile:"rilova-app-icon.svg",atomically:true,encoding:.utf8)
png("brand-board.png",1800,1300){c in
 c.setFillColor(color("F6F3EB"));c.fill(.init(x:0,y:0,width:1800,height:1300))
 text(c,"RILOVA / FLOWING R",90,100,25,"466F6B")
 c.saveGState();c.translateBy(x:0,y:90);c.scaleBy(x:0.72,y:0.72);lockup(c,"072E32");c.restoreGState()
 icon(c,1250,155,390,rounded:true)
 c.setFillColor(color("072E32"));c.fill(.init(x:0,y:600,width:1800,height:430))
 c.saveGState();c.translateBy(x:0,y:600);c.scaleBy(x:0.62,y:0.62);lockup(c,"F9FAF0");c.restoreGState()
 icon(c,1260,680,260,dark:true,rounded:true)
 text(c,"Default · mint to teal",1250,590,24,"072E32");text(c,"Dark appearance",1250,990,24,"F9FAF0")
 text(c,"SMALL-SIZE CHECK",90,1110,23,"466F6B")
 for (i,s) in [CGFloat(120),60,40,29].enumerated(){icon(c,95+CGFloat(i)*180,1150,s,rounded:true)}
 text(c,"Flowing R · Solid marks · System-masked icons",860,1210,24,"072E32")
}
print("Rendered flowing-R assets")
