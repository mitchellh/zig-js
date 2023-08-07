try {
    console.log(this);
    
    const example = {
        description: "This message is passed from a zig @embed()'ed js string in wasm.",
        msg: "Hello World from zig-js",
    };
    console.log(example);
    
    const div = document.createElement('pre');
    div.style.backgroundColor = "lightgray";
    div.innerText = JSON.stringify(example, null, 4);
    document.body.appendChild(div);
} catch (error) {
    console.error(error);
}
// the last statement needs to be a returnable value
null;