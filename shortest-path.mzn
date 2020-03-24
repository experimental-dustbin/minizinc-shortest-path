int: rows = 7;
int: cols = 7;
% 0/1 matrix that represents the maze. 0 means the point is accessible
% and 1 means it's not. You can think of 1's as walls and 0's as ground.
array[1..rows, 1..cols] of 0..1: maze = [|
  0, 1, 0, 0, 0, 0, 0|
  0, 1, 0, 1, 1, 1, 0|
  0, 1, 0, 0, 0, 1, 0|
  0, 1, 0, 1, 0, 1, 0|
  0, 1, 1, 0, 0, 1, 0|
  0, 1, 0, 0, 1, 0, 0|
  0, 0, 0, 0, 1, 0, 0|];
% Another 0/1 matrix that encodes points on a path in the maze. 1 means the
% point is on the path and 0 means it's not. This is what we are trying to get
% MiniZinc to fill in for us.
array[1..rows, 1..cols] of var 0..1: path;
% We perform a "convolution" along the path to compute some local statistics
% for each point on the path. These numbers will then allows us to express certain
% constraints to rule out invalid paths.
array[1..rows, 1..cols] of var int: convolution;
% Walls can not be in the path so we are forced to set those points to 0
% in any valid path.
constraint forall(r in 1..rows, c in 1..cols where maze[r, c] = 1)(
  path[r, c] = 0
);
% Starting and ending points must be in the path.
constraint path[1, 1] = 1 /\ path[rows, cols] = 1;
% Let's do some "convolutions". Really what we are doing is counting neighboring points.
% Neighboring point means we can access that point by going up/down/left/right. We
% specify the boundary points first because at the boundaries we can't go in certain directions.
constraint convolution[1, 1] = sum([path[1, 1], path[1, 2], path[2, 1]]) /\
  convolution[1, cols] = sum([path[1, cols], path[1, cols - 1], path[2, cols]]) /\
  convolution[rows, cols] = sum([path[rows, cols], path[rows - 1, cols], path[rows, cols - 1]]) /\
  convolution[rows, 1] = sum([path[rows, 1], path[rows, 2], path[rows - 1, 1]]);
% Next do the boundary segments between the boundary points like top and bottom row and first and last columns.
% We again special case these segments because we have to be careful to not go outside the bounds of the maze.
% top (r = 1, 2 < c < cols - 1),
constraint forall(c in 2..cols - 1)(
  convolution[1, c] = if path[1, c] = 1 then
    sum([path[1, c], path[1, c - 1], path[2, c], path[1, c + 1]])
  else
    0
  endif
) /\
% right (2 < r < rows - 1, c = cols),
forall(r in 2..rows - 1)(
  convolution[r, cols] = if path[r, cols] = 1 then
    sum([path[r, cols], path[r - 1, cols], path[r + 1, cols], path[r, cols - 1]])
  else
    0
  endif
) /\
% bottom (r = rows, 2 < c < cols - 1),
forall(c in 2..cols - 1)(
  convolution[rows, c] = if path[rows, c] = 1 then
    sum([path[rows, c], path[rows, c - 1], path[rows, c + 1], path[rows - 1, c]])
  else
    0
  endif
) /\
% left (2 < r < rows - 1, c = 1).
forall(r in 2..rows - 1)(
  convolution[r, 1] = if path[r, 1] = 1 then
    sum([path[r, 1], path[r - 1, 1], path[r + 1, 1], path[r, 2]])
  else
    0
  endif
) /\
% Now we can handle all the points not on the boundaries.
forall(r in 2..rows - 1, c in 2..cols - 1)(
  convolution[r, c] = if path[r, c] = 1 then
    sum([path[r, c], path[r + 1, c], path[r - 1, c], path[r, c - 1], path[r, c + 1]])
  else
    0
  endif
);
output ["Convolution: ", show2d(convolution)];
output ["Path: ", show2d(path)];
% % Now we put some constraints on the points in the path by saying the convolution on a path point
% % must satisfy a certain requirement like the boundary points must always have convolutions of at
% % least 2 and points on the interior of the path must have convolutions of at least 3.
constraint convolution[1, 1] > 1 /\ % Starting point.
convolution[rows, cols] > 1 /\ % Ending point.
(path[1, cols] = 1 -> convolution[1, cols] > 2) /\ % Top right.
(path[rows, 1] = 1 -> convolution[rows, 1] > 2); % Bottom left.
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
forall(r in 2..rows - 1, c in 2..cols - 1)( % All other/interior/non-boundary points.
  path[r, c] = 1 -> convolution[r, c] > 2
);
% % With those specifications we can now find paths of minimal length.
var int: pathCost = sum(r in 1..rows, c in 1..cols where path[r, c] = 1)(1);
output ["Path cost: \(pathCost)."];
solve minimize pathCost;
% % Every row and column must be in the path somewhere because we must traverse every row
% % and column between the starting and ending points to get to the destination.
% % Take out this condition to see what happens. Why is this required to make the path "continuous"?
% % constraint forall(r in 1..rows)(
% %   exists(c in 1..cols)(
% %     path[r, c] = 1
% %   )
% % ) /\
% % forall(c in 1..cols)(
% %   exists(r in 1..rows)(
% %     path[r, c] = 1
% %   )
% % );
% % When the above condition is taken out we get disconnected components like so
% % [| 1, 0, 0, 0, 0, 0, 0 |
% %    1, 0, 0, 0, 0, 0, 0 |
% %    1, 0, 0, 0, 0, 0, 0 |
% %    1, 0, 0, 0, 0, 0, 0 |
% %    1, 0, 0, 0, 0, 0, 0 |
% %    1, 0, 1, 1, 0, 1, 1 |
% %    1, 1, 1, 1, 0, 1, 1 |]
% % Notice how this path is split into 2 parts with a column of 0's separting the two parts.
% % Each path component locally satisfies the requirements but that column of 0's means our
% % path is invalid. So we need a way of ruling out such cases. We could say this isn't allowed, i.e.
% % We can't have a column or row of 0's separting parts of the path.
constraint not exists(c in 1..cols)(
  forall(r in 1..rows)(
    path[r, c] = 0
  )
) /\
% The above condition rules out any column based separation but if we can have columns cutting the path
% then we can also have rows so we also rule those out.
not exists(r in 1..rows)(
  forall(c in 1..cols)(
    path[r, c] = 0
  )
);
% % I'm actually not sure if the above conditions are really necessary. There might be some other conditions
% % that will also work, like the one we had initially that required every row/column to have at least 1 element
% % on the path.