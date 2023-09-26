// DEPENDENCIES
import { readFileSync, existsSync, fstat, readFile } from 'fs';
import express from 'express';
import crypto from 'crypto';
const app = express();
const port = `5001`;
import cors from 'cors';

// LOAD LIBRARIES
app.use(cors());

//DECLARE GLOBAL VARS
var items = []; 

function getId(type, name, created_at) {
    const uin8array = new TextEncoder().encode('PPRLSS::'+type+name+created_at);
    return crypto.subtle.digest('SHA-256', uin8array);
}

async function getFileHash(file) {
    //Load file from path and convert contents into UInt8Array
    const uin8array = new Uint8Array(readFileSync(file));
    //Compute sha-256 hash from UInt8Array into a new UInt8Array
    const hashBuffer = await crypto.subtle.digest('SHA-256', uin8array);
    //Convert the UInt8Array back into a bit array
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    //Convert the bit array back into a string and return the promise for that
    return hashArray.map((h) => h.toString(16).padStart(2, '0')).join('');
}

class itemObject {
    constructor(type, name, created_at, updated_at, file_name, file_location) {
        var obj = this;
        this.type = type;
        this.name = name;
        this.created_at = created_at;
        this.updated_at = updated_at;
        this.file_name = file_name;
        this.file_location = file_location;
        this.file_size = fstat(file_name);
        this.id = getId(type, name, created_at);
        getFileHash(file_location + '/' + file_name).then(hash => {
            this.file_hash = hash;
        });

        this.toString = function () {
            return JSON.stringify(obj);
        };
    }
}


function loadToItems(obj) {
    items.push( new itemObject(obj.type, obj.name, obj.created_at, obj.updated_at, obj.file_name, obj.file_location));
}

// API ENDPOINTS
app.get('/file', async (req, res) => {
    const fileTypes = [
        "pdf"
    ];

    console.log('Got API Request for ' + JSON.stringify(req.query));
    // Check if the right request is coming through for the file type
    try {
        const file = await new Promise((resolve, reject) => {
            let ftype = JSON.stringify(req.query.file).replace(/[ &\/\\#,+()$~%'":*?<>{}]/g, "").match(/(?<=\.)([\w]+)$/g)[0].toLowerCase();
            if (req.query.file && fileTypes.includes(ftype)) {
                return resolve(JSON.stringify(req.query.file).replace(/[ &\/\\#,+()$~%'":*?<>{}]/g, "")); //Remove unallowed fs chars
            } else {
                return reject(`Please provide a file type of ?file=${fileTypes.join('|')}`);}
        });
        const filePath = await new Promise((resolve_1, reject_1) => {
            if (existsSync(`./files/${file}`)) {
                return resolve_1(`./files/${file}`);
            }
            return reject_1(`File '${file}' was not found.`);
        });
        res.download(filePath);
    } catch (e) {
        res.status(400).send(e);
    }
});


app.get('/last-update', async(_req, res) => {
    try {
        const lastupdateTS = Date.now();
        res.status(200).json({last_update: lastupdateTS});
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request ${e}`,
        });
    }
});

app.get('/items', async(_req, res) => {
    try {
        res.status(200).json(items);
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items/delete', async(_req, res) => {
    try {
        res.status(200);
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items/update', async(_req, res) => {
    try {
        res.status(200).send({
            message: ''
        });
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items/create', async(_req, res) => {
    try {
        res.status(200).send({
            message: ''
        });
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items/template/container', async(_req, res) => {
    try {
        res.status(200).send(JSON.parse(readFileSync('./items/template/container.json').toString()));
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items/template/document', async(_req, res) => {
    try {
        res.status(200).send(JSON.parse(readFileSync('./items/template/document.json').toString()));
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

app.get('/items/template/file', async(_req, res) => {
    try {
        res.status(200).send(JSON.parse(readFileSync('./items/template/file.json').toString()));
    } catch (e) {
        res.status(400).send({
            message: `Encountered error while processing request: ${e}`,
        });
    }
});

async function main() {
    var jsonItems = JSON.parse(readFileSync('./items/items.json').toString());
    await jsonItems.items.forEach((element) => loadToItems(element)); 
}

await main();

// HTTP SERVER
app.listen(port, () => console.log(`Listening on port ${port}`));