/* Excerpted from d3 */

var abs, d3_geom_quadtreeCompatX, d3_geom_quadtreeCompatY, d3_geom_quadtreeNode, d3_geom_quadtreeVisit;

d3_geom_quadtreeCompatX = function(d) {
  return d.x;
};

d3_geom_quadtreeCompatY = function(d) {
  return d.y;
};

d3_geom_quadtreeNode = function() {
  return {
    leaf: true,
    nodes: [],
    point: null,
    x: null,
    y: null
  };
};

d3_geom_quadtreeVisit = function(f, node, x1, y1, x2, y2) {
  var children, sx, sy;
  if (!f(node, x1, y1, x2, y2)) {
    sx = (x1 + x2) * 0.5;
    sy = (y1 + y2) * 0.5;
    children = node.nodes;
    if (children[0]) {
      d3_geom_quadtreeVisit(f, children[0], x1, y1, sx, sy);
    }
    if (children[1]) {
      d3_geom_quadtreeVisit(f, children[1], sx, y1, x2, sy);
    }
    if (children[2]) {
      d3_geom_quadtreeVisit(f, children[2], x1, sy, sx, y2);
    }
    if (children[3]) {
      return d3_geom_quadtreeVisit(f, children[3], sx, sy, x2, y2);
    }
  }
};

abs = Math.abs;

window.quadtree = function(points, x1, y1, x2, y2) {
  var quadtree, x, y;
  quadtree = function(data) {
    var d, dx, dy, fx, fy, i, insert, insertChild, n, root, x1_, x2_, xs, y1_, y2_, ys;
    insert = function(n, d, x, y, x1, y1, x2, y2) {
      var nPoint, nx, ny;
      if (isNaN(x) || isNaN(y)) {
        return;
      }
      if (n.leaf) {
        nx = n.x;
        ny = n.y;
        if (nx != null) {
          if ((abs(nx - x) + abs(ny - y)) < 0.01) {
            return insertChild(n, d, x, y, x1, y1, x2, y2);
          } else {
            nPoint = n.point;
            n.x = n.y = n.point = null;
            insertChild(n, nPoint, nx, ny, x1, y1, x2, y2);
            return insertChild(n, d, x, y, x1, y1, x2, y2);
          }
        } else {
          n.x = x;
          n.y = y;
          return n.point = d;
        }
      } else {
        return insertChild(n, d, x, y, x1, y1, x2, y2);
      }
    };
    insertChild = function(n, d, x, y, x1, y1, x2, y2) {
      var below, i, right, xm, ym;
      xm = (x1 + x2) * 0.5;
      ym = (y1 + y2) * 0.5;
      right = x >= xm;
      below = y >= ym;
      i = below << 1 | right;
      n.leaf = false;
      n = n.nodes[i] || (n.nodes[i] = d3_geom_quadtreeNode());
      if (right) {
        x1 = xm;
      } else {
        x2 = xm;
      }
      if (below) {
        y1 = ym;
      } else {
        y2 = ym;
      }
      return insert(n, d, x, y, x1, y1, x2, y2);
    };
    d = void 0;
    fx = x;
    fy = y;
    xs = void 0;
    ys = void 0;
    i = void 0;
    n = void 0;
    x1_ = void 0;
    y1_ = void 0;
    x2_ = void 0;
    y2_ = void 0;
    if (x1 != null) {
      x1_ = x1;
      y1_ = y1;
      x2_ = x2;
      y2_ = y2;
    } else {
      x2_ = y2_ = -(x1_ = y1_ = Infinity);
      xs = [];
      ys = [];
      n = data.length;
      i = 0;
      while (i < n) {
        d = data[i];
        if (d.x < x1_) {
          x1_ = d.x;
        }
        if (d.y < y1_) {
          y1_ = d.y;
        }
        if (d.x > x2_) {
          x2_ = d.x;
        }
        if (d.y > y2_) {
          y2_ = d.y;
        }
        xs.push(d.x);
        ys.push(d.y);
        ++i;
      }
    }
    dx = x2_ - x1_;
    dy = y2_ - y1_;
    if (dx > dy) {
      y2_ = y1_ + dx;
    } else {
      x2_ = x1_ + dy;
    }
    root = d3_geom_quadtreeNode();
    root.visit = function(f) {
      return d3_geom_quadtreeVisit(f, root, x1_, y1_, x2_, y2_);
    };
    i = -1;
    if (x1 == null) {
      while (++i < n) {
        insert(root, data[i], xs[i], ys[i], x1_, y1_, x2_, y2_);
      }
      --i;
    } else {
      data.forEach(root.add);
    }
    xs = ys = data = d = null;
    return root;
  };
  x = d3_geom_quadtreeCompatX;
  y = d3_geom_quadtreeCompatY;
  return quadtree(points);
};
