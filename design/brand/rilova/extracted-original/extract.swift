import AppKit
// Deterministic owner-authorized extraction; reconstruct only background corners.
let url=URL(fileURLWithPath:CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "source-board.png")
let src=NSImage(contentsOf:url)!.cgImage(forProposedRect:nil,context:nil,hints:nil)!
let space=CGColorSpace(name:CGColorSpace.sRGB)!,sw=src.width,sh=src.height,n=388
var input=[UInt8](repeating:0,count:sw*sh*4)
input.withUnsafeMutableBytes{b in let c=CGContext(data:b.baseAddress,width:sw,height:sh,bitsPerComponent:8,bytesPerRow:sw*4,space:space,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!;c.draw(src,in:.init(x:0,y:0,width:sw,height:sh))}
func inside(_ x:Int,_ y:Int,_ m:Double)->Bool{let px=Double(x)+0.5,py=Double(y)+0.5,r=97.0;let dx=max(r-px,px-(Double(n)-r),0),dy=max(r-py,py-(Double(n)-r),0);return px>=m && py>=m && px<Double(n)-m && py<Double(n)-m && dx*dx+dy*dy<pow(r-m,2)}
func terms(_ x:Int,_ y:Int)->[Double]{let u=Double(x)/387,v=Double(y)/387;return [1,u,v,u*u,u*v,v*v,u*u*u,u*u*v,u*v*v,v*v*v]}
func solve(_ a:[[Double]],_ b:[Double])->[Double]{var m=a;for i in 0..<10{m[i].append(b[i])};for k in 0..<10{let p=(k..<10).max{abs(m[$0][k])<abs(m[$1][k])}!;m.swapAt(p,k);let d=m[k][k];precondition(abs(d)>1e-12);for j in k...10{m[k][j]/=d};for i in 0..<10 where i != k{let v=m[i][k];for j in k...10{m[i][j]-=v*m[k][j]}}};return (0..<10).map{m[$0][10]}}
func image(_ bytes:[UInt8],_ w:Int,_ h:Int)->CGImage{CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:space,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.noneSkipLast.rawValue),provider:CGDataProvider(data:Data(bytes) as CFData)!,decode:nil,shouldInterpolate:true,intent:.defaultIntent)!}
func save(_ im:CGImage,_ name:String,_ pixels:Int?=nil){var result=im;if let pixels{let c=CGContext(data:nil,width:pixels,height:pixels,bitsPerComponent:8,bytesPerRow:pixels*4,space:space,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!;c.interpolationQuality = .high;c.draw(im,in:.init(x:0,y:0,width:pixels,height:pixels));result=c.makeImage()!};let b=NSBitmapImageRep(cgImage:result);try! b.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:name))}
var outputs:[CGImage]=[]
for (name,left,top) in [("gradient",688,439),("dark",178,439)]{
 var a=[[Double]](repeating:[Double](repeating:0,count:10),count:10),b=[[Double]](repeating:[Double](repeating:0,count:10),count:3)
 for y in stride(from:0,to:n,by:4){for x in stride(from:0,to:n,by:4){guard inside(x,y,8),!(x>=82 && x<=312 && y>=70 && y<=318) else{continue};let f=terms(x,y),index=((top+y)*sw+left+x)*4;for i in 0..<10{for j in 0..<10{a[i][j]+=f[i]*f[j]};for ch in 0..<3{b[ch][i]+=f[i]*Double(input[index+ch])}}}}
 let coeff=b.map{solve(a,$0)};var bytes=[UInt8](repeating:255,count:n*n*4),kept=0
 for y in 0..<n{for x in 0..<n{let target=(y*n+x)*4,original=((top+y)*sw+left+x)*4;if inside(x,y,4){for ch in 0..<3{bytes[target+ch]=input[original+ch]};kept+=1}else{let f=terms(x,y);for ch in 0..<3{let v=zip(f,coeff[ch]).reduce(0){$0+$1.0*$1.1};bytes[target+ch]=UInt8(max(0,min(255,v.rounded())))}}}}
 for y in 70...318{for x in 82...312{let p=(y*n+x)*4,q=((top+y)*sw+left+x)*4;for ch in 0..<3{precondition(bytes[p+ch]==input[q+ch])}}}
 let im=image(bytes,n,n);outputs.append(im);save(im,"rilova-\(name)-native.png");save(im,"rilova-\(name)-1024.png",1024)
 print("\(name): \(kept) original pixels retained; symbol rectangle identical; 388px source / 1024px interpolated export")
}
let c=CGContext(data:nil,width:1400,height:860,bitsPerComponent:8,bytesPerRow:1400*4,space:space,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
c.setFillColor(CGColor(colorSpace:space,components:[0.965,0.953,0.929,1])!);c.fill(.init(x:0,y:0,width:1400,height:860))
for (i,im) in outputs.enumerated(){let x=CGFloat(100+i*680);let r=CGRect(x:x,y:325,width:388,height:388);c.saveGState();c.addPath(CGPath(roundedRect:r,cornerWidth:97,cornerHeight:97,transform:nil));c.clip();c.draw(im,in:r);c.restoreGState();for (j,s) in [CGFloat(120),60,40,29].enumerated(){let rect=CGRect(x:x+CGFloat(j)*130,y:155,width:s,height:s);c.saveGState();c.addPath(CGPath(roundedRect:rect,cornerWidth:s/4,cornerHeight:s/4,transform:nil));c.clip();c.draw(im,in:rect);c.restoreGState()}}
save(c.makeImage()!,"extracted-preview.png")
