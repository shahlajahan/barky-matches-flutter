const fs = require("fs");

const raw = require("./data/raw_tr.json");

// تبدیل ساختار خام به ساختار admin1/admin2
const output = {
    admin1: []
};

let sortProvince = 1;

Object.keys(raw).sort().forEach((provinceCode) => {
    const province = raw[provinceCode];

    const admin1 = {
        id: provinceCode,
        name: province.name,
        name_local: province.name,
        sort: sortProvince++,
        districts: []
    };

    let sortDistrict = 1;

    province.districts.sort().forEach((d) => {
        admin1.districts.push({
            id: d.toUpperCase().substring(0, 5),
            name: d,
            sort: sortDistrict++
        });
    });

    output.admin1.push(admin1);
});

fs.writeFileSync(
    "./data/tr_provinces_districts.json",
    JSON.stringify(output, null, 2)
);

console.log("✅ tr_provinces_districts.json generated successfully");