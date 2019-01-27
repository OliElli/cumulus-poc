#!/bin/bash
cp topology.dot graph.dot
sed -i 's/:"swp/:"/g' graph.dot
dot -Tpng -ograph.png graph.dot
rm graph.dot
