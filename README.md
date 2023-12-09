# Windows API Covert lastwritetime

I was trying to follow along with the following blog https://gtworek.github.io/PSBits/lastwritetime.html to modify the last write time without evidence appearing in the NTFS journal

A majority of the method declarations are ChatGPT goop mixed with Pinvoke https://www.pinvoke.net/

I'm not sure which of my method definitions are incorrect, could just be WriteFile or all of them. Pinvoke hasnt been maintined either and has a lot of graffiti

Main file is testRaw
