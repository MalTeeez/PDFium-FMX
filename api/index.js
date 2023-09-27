// DEPENDENCIES
import { readFileSync, existsSync, statSync} from 'fs';
import express from 'express';
import crypto from 'crypto';
const app = express();
const port = `5001`;
import cors from 'cors';

// LOAD LIBRARIES
app.use(cors()).use(express.json());

//DECLARE GLOBAL VARS
var items = []; 

function removeItemById(id) {
    items.forEach(item => {
        if (item.id === id) {
            const index = items.indexOf(item);
            if (index > -1) {
                items.splice(index, 1);
            }
        }
    });
}

function getItemById(id) {
    items.forEach(item => {
        if (item.id === id) {
            const index = items.indexOf(item);
            if (index > -1) {
                return item;
            }
        }
    });
}

function getItemsByName(name) {
    let res = [];
    items.forEach(item => {
        if (item.name === name) {
            const index = items.indexOf(item);
            if (index > -1) {
                res.push(item);
            }
        }
    });
    return res;
}

function addFileToItem(item, file_name, file_location) {
    item.setFileName = file_name;
    item.setFileLocation = file_location;

    let file_path = file_location + '/' + file_name;
    this.file_size = statSync(file_path).size;
    getFileHash(file_path).then(hash => {
        this.file_hash = hash;
    });
}

async function getStringHash(type, name, created_at) {
    const uin8array = new TextEncoder().encode('PPRLSS::'+type+name+created_at);
    const hashBuffer = await crypto.subtle.digest('SHA-256', uin8array);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    return hashArray.map((h) => h.toString(16).padStart(2, '0')).join('');
}

async function getFileHash(file_path) {
    let file = readFileSync(file_path);
    //Load file from path and convert contents into UInt8Array
    const uin8array = new Uint8Array(file);
    //Compute sha-256 hash from UInt8Array into a new UInt8Array
    const hashBuffer = await crypto.subtle.digest('SHA-256', uin8array);
    //Convert the UInt8Array back into a bit array
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    //Convert the bit array back into a string and return the promise for that
    return hashArray.map((h) => h.toString(16).padStart(2, '0')).join('');
}


class itemObject {
    constructor(type, name, created_at, updated_at, _file_name, _file_location) {
        this.type = type;
        this.name = name;
        this.created_at = created_at;
        this.updated_at = updated_at;
        getStringHash(type, name, created_at).then(id => {
            this.id = id;
        });

        if (_file_name && _file_location) {
            this.file_name = _file_name;
            this.file_location = _file_location;
            
            let file_path = file_location + '/' + file_name;
            this.file_size = statSync(file_path).size;
            getFileHash(file_path).then(hash => {
                this.file_hash = hash;
            });
        }
    }

    setFileName(file_name) {
        this.file_name = file_name;
    }

    setFileLocation(file_location) {
        this.file_name = file_location;
    }

    toString() {
        return JSON.stringify(obj);
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

    console.log('Got File API Request for ' + JSON.stringify(req.query));
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

app.get('/items/delete', async(req, res) => {
    try {
        removeItemById(req.query.id);
        res.status(200).send({
            message: `Item with Id ${req.query.id} was successfully deleted.`,
        });
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

app.post('/items/create', async(req, res) => {
    try {
        loadToItems(req.body);
        res.status(200).send({
            message: `Item with Name ${req.body.name} was successfully created.`,
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