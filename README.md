# Finding paths in a maze with MiniZinc
There are many ways to find paths in a maze but today we're going to do find it declaratively with MiniZinc. We'll express parts of the problem like the maze and the path with 0/1 matrices and then specify constraints on the path matrix to make sure we get valid paths.

# Initial parameters
Our starting point is the maze and it's a 7x7 grid/matrix where the starting point is at the top/left and the ending point is at the bottom right.

```
int: rows = 7;
int: cols = 7;
array[1..rows, 1..cols] of 0..1: maze = [|
  0, 1, 0, 0, 0, 0, 0|
  0, 1, 0, 1, 1, 1, 0|
  0, 1, 0, 0, 0, 1, 0|
  0, 1, 0, 1, 0, 1, 0|
  0, 1, 1, 0, 0, 1, 0|
  0, 1, 0, 0, 1, 0, 0|
  0, 0, 0, 0, 1, 0, 0|]
```

This is called a 0/1 matrix and it specifies the ground points with 0s and walls with 1s. As far as mazes go this isn't
that complicated but it demonstrates how at various points we must "backtrack" and go in the opposite direction from our
destination. It's just complicated enough to rule out the easy case of always moving towards our goal so we will need to
think of how to specify validity of paths even when there is backtracking involved.

The other parameters are the path matrix and the path convolution matrix. The path matrix is another 0/1 matrix where 1s represent points on the path and the convolution matrix will represent certain local statistics about the path (in this case we will be counting neighboring points). The combination of these two matrices will let us specify constraints that rule out invalid paths.

```
array[1..rows, 1..cols] of var 0..1: path;
array[1..rows, 1..cols] of var int: convolution;
```

_A note: one thing that takes some getting used to when specifying problems using a declarative language is a "wholesale" approach
to specifying parts of the problem where we just assume something exists instead of constructing it incrementally. If we were
doing some kind of depth-first search of the maze to find a path from the starting point to the destination point then we'd be
constructing and testing the path incrementally by looking at where we are and then extending the path in some direction. In a declarative context we assume the path exists and then think about what
properties it must satisfy. We don't worry about constructing the path but try to think of ways to specify properties that will
force the path to be "correct" assuming we already have the whole thing._

# Initial constraints
We now have everything we need to start specifying constraints for the paths.

One obvious constraint is that walls can not be part of a path so all walls must be 0 in the path matrix.

```
constraint forall(r in 1..rows, c in 1..cols
  where maze[r, c] = 1)(path[r, c] = 0);
```

That says for every point in the maze where there is a 1 (wall) we must have a 0 in the path matrix. We can't "step" on walls.

Next we specify that our starting (top/left) and ending (bottom/right) points must be on the path.

```
constraint path[1, 1] = 1 /\ % Top/left.
  path[rows, cols] = 1; % Bottom/right.
```

That's mostly it for the path for now and we can switch gears and specify constraints on the convolution matrix. We first have to consider "boundary" points and specify what happens when one of the points on the path is near the edges because when we are at the edge we'll have to be careful to not use indices that will be out of bounds. This is slightly tedious but not complicated, we just make sure to avoid going outside the boundaries of the maze and for each point we count how many other neighboring/near points are also on the same path. Near is defined as immediatly to the left/right/above/below the point we are currently at. Since we are using a 0/1 matrix to represent the path we can just sum the neighboring points to get the desired count. Any point not on the path will be 0 and so will not contribute to our neighborhood count.

```
constraint convolution[1, 1] = sum([ % Top/left.
  path[1, 1],
  path[1, 2],
  path[2, 1]]) /\
convolution[1, cols] = sum([ % Top/right
  path[1, cols],
  path[1, cols - 1],
  path[2, cols]]) /\
convolution[rows, cols] = sum([ % Bottom/right.
  path[rows, cols],
  path[rows - 1, cols],
  path[rows, cols - 1]]) /\
convolution[rows, 1] = sum([ % Bottom/left.
  path[rows, 1],
  path[rows, 2],
  path[rows - 1, 1]]);
```

Those are the boundary points and we do the same for the boundary segments. Boundary segment just means all the points in the first row, first column, last row, last column without their endpoints because we already accounted for those above.

Again this is tedius but not complicated and is just a matter of making sure we don't index outside the boundaries of the maze by being careful about how we index the path matrix.

```
% Top (r = 1, 2 < c < cols - 1),
constraint forall(c in 2..cols - 1)(
  convolution[1, c] = if path[1, c] = 1 then
    sum([
      path[1, c],
      path[1, c - 1], % Left.
      path[2, c], % Below.
      path[1, c + 1]]) % Right.
  else
    0
  endif
) /\
% Right (2 < r < rows - 1, c = cols),
forall(r in 2..rows - 1)(
  convolution[r, cols] = if path[r, cols] = 1 then
    sum([
      path[r, cols],
      path[r - 1, cols], % Above.
      path[r + 1, cols], % Below.
      path[r, cols - 1]]) % Left.
  else
    0
  endif
) /\
% Bottom (r = rows, 2 < c < cols - 1),
forall(c in 2..cols - 1)(
  convolution[rows, c] = if path[rows, c] = 1 then
    sum([
      path[rows, c],
      path[rows, c - 1], % Left.
      path[rows, c + 1], % Right.
      path[rows - 1, c]]) % Above.
  else
    0
  endif
) /\
% Left (2 < r < rows - 1, c = 1).
forall(r in 2..rows - 1)(
  convolution[r, 1] = if path[r, 1] = 1 then
    sum([
      path[r, 1],
      path[r - 1, 1], % Above.
      path[r + 1, 1], % Below.
      path[r, 2]]) % Right.
  else
    0
  endif
);
```

With the boundary taken care of we can now specify the constraints for the remaining/interior points.

```
constraint forall(r in 2..rows - 1, c in 2..cols - 1)(
  convolution[r, c] = if path[r, c] = 1 then
    sum([
      path[r, c],
      path[r + 1, c], % Below.
      path[r - 1, c], % Above.
      path[r, c - 1], % Left.
      path[r, c + 1]]) % Right.
  else
    0
  endif
);
```

At this point I recommend running the model to see what solutions/paths and convolutions look like.

```
output ["Convolution: ", show2d(convolution)];
output ["Path: ", show2d(path)];
```

I get a very boring answer.

```
Convolution: [|
   1, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 1 |]
Path: [|
   1, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 0 |
   0, 0, 0, 0, 0, 0, 1 |]
```

It's the absolute minimum that satisfies our requirements. Only the starting and ending points are there and the path is clearly not valid because it just consists of two points. We'll incrementally add more requirements until our paths start looking like real paths.

# Ruling out incorrect paths
One obvious thing we can do to improve the situation is specify that the starting and ending points can't be isolated. This means that they must have at least 1 neighbor so their convolution count must be at least 2. Similar reasoning should convince you that the other boundary points must have at least 2 neighbors so the convolution count must be at least 3.

```
constraint convolution[1, 1] > 1 /\ % Starting point.
convolution[rows, cols] > 1 /\ % Ending point.
(path[1, cols] = 1 -> convolution[1, cols] > 2) /\ % Top right.
(path[rows, 1] = 1 -> convolution[rows, 1] > 2); % Bottom left.
```

If you run the model now you will get something slightly less trivial but it's still pretty bad. We also need to think about what properties must be true for non-terminal points of the path. For the interior/non-terminal points we must have come to that point from somewhere and must be going somewhere else. This is another way of saying that interior points must have at least 2 neighbors so their convolution count must be at least 3.

```
constraint forall(c in 2..cols - 1)( % Top interior.
  path[1, c] = 1 -> convolution[1, c] > 2
) /\
forall(r in 2..rows - 1)( % Right interior.
  path[r, cols] = 1 -> convolution[r, cols] > 2
) /\
forall(c in 2..cols - 1)( % Bottom interior.
  path[rows, c] = 1 -> convolution[rows, c] > 2
) /\
forall(r in 2..rows - 1)( % Left interior.
  path[r, 1] = 1 -> convolution[r, 1] > 2
) /\
forall(r in 2..rows - 1, c in 2..cols - 1)( % All other points.
  path[r, c] = 1 -> convolution[r, c] > 2
);
```

Now things start to get interesting. We start to get non-trivial paths and can start thinking about minimizing the distance we have to travel, i.e. we want to get from the start to the end as fast as possible so we want the path with the least length/cost.

```
var int: pathCost = sum(
  r in 1..rows,
  c in 1..cols
  where path[r, c] = 1)(1);
output ["Path cost: \(pathCost)."];
solve minimize pathCost;
```

Running this gives us an even more interesting result but something is still wrong.

```
Path: [|
   1, 0, 0, 0, 0, 0, 0 |
   1, 0, 0, 0, 0, 0, 0 |
   1, 0, 0, 0, 0, 0, 0 |
   1, 0, 0, 0, 0, 0, 0 |
   1, 0, 0, 0, 0, 0, 0 |
   1, 0, 1, 1, 0, 1, 1 |
   1, 1, 1, 1, 0, 1, 1 |]
```

This path is split into two parts. There is a column of 0s splitting the path into 2 parts. We want to rule this out and there are probably a few ways to do that but I could only think of one way which was to just rule out any columns/rows of 0s in the path matrix.

```
constraint not exists(c in 1..cols)(
  forall(r in 1..rows)(
    path[r, c] = 0
  )
) /\
not exists(r in 1..rows)(
  forall(c in 1..cols)(
    path[r, c] = 0
  )
);
```

Now I get the desired result, a connected path that has the minimum number of steps required to get from the start to the end.

```
Path: [|
   1, 0, 1, 1, 1, 1, 1 |
   1, 0, 1, 0, 0, 0, 1 |
   1, 0, 1, 1, 1, 0, 1 |
   1, 0, 0, 0, 1, 0, 1 |
   1, 0, 0, 1, 1, 0, 1 |
   1, 0, 1, 1, 0, 0, 1 |
   1, 1, 1, 0, 0, 0, 1 |]
Path cost: 29.
```

# Further exploration
The next step would be to figure out how to deal with paths and mazes where the starting and ending points are not the top/left and bottom/right points. If you figure it out let me know.