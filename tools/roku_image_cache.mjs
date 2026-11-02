// The original image is retained separately; this produces the bounded display copy.
export async function fitArtwork(sharp,input){return sharp(input).resize({width:192,height:108,fit:'contain',background:{r:0,g:0,b:0,alpha:0}}).png({palette:true,colours:128,quality:95,effort:1,dither:0.1,compressionLevel:9}).toBuffer();}
