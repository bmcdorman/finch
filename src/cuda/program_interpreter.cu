#include <finch/geometry.hpp>
#include <finch/program_state.hpp>

#include <stdio.h>

using namespace finch;

__device__ bool occurence_in_cone_east(uint16_t *const maze, const uint16_t rows, const uint16_t cols,
  uint16_t r, uint16_t c, const uint16_t val)
{
  const int16_t out = c;
  const int16_t in = r;
  const int16_t in_max = rows;
  const int16_t dir = 1;
  for(int16_t oi = out, k = 0; oi >= 0; oi += dir, ++k) {
    const int16_t bound1 = (in - k < 0 ? 0 : in - k);
    const int16_t bound2 = (in + k > in_max - 1 ? in_max - 1 : in + k);
    for(int16_t ii = bound1; ii < bound2; ++ii) {
      if(maze[ii * cols + oi] == 2) return true;
    }
  }
  return false;
}

__device__ bool occurence_in_cone_north(uint16_t *const maze, const uint16_t rows, const uint16_t cols,
  uint16_t r, uint16_t c, const uint16_t val)
{
  const int16_t out = r;
  const int16_t in = c;
  const int16_t in_max = cols;
  const int16_t dir = -1;
  for(int16_t oi = out, k = 0; oi >= 0; oi += dir, ++k) {
    const int16_t bound1 = (in - k < 0 ? 0 : in - k);
    const int16_t bound2 = (in + k > in_max - 1 ? in_max - 1 : in + k);
    for(int16_t ii = bound1; ii < bound2; ++ii) {
      if(maze[oi * cols + ii] == 2) return true;
    }
  }
  return false;
}

__device__ bool occurence_in_cone_west(uint16_t *const maze, const uint16_t rows, const uint16_t cols,
  uint16_t r, uint16_t c, const uint16_t val)
{
  const int16_t out = c;
  const int16_t in = r;
  const int16_t in_max = rows;
  const int16_t dir = -1;
  for(int16_t oi = out, k = 0; oi >= 0; oi += dir, ++k) {
    const int16_t bound1 = (in - k < 0 ? 0 : in - k);
    const int16_t bound2 = (in + k > in_max - 1 ? in_max - 1 : in + k);
    for(int16_t ii = bound1; ii < bound2; ++ii) {
      if(maze[ii * cols + oi] == 2) return true;
    }
  }
  
  return false;
}

__device__ bool occurence_in_cone_south(uint16_t *const maze, const uint16_t rows, const uint16_t cols,
  uint16_t r, uint16_t c, const uint16_t val)
{
  const int16_t out = r;
  const int16_t in = c;
  const int16_t in_max = cols;
  const int16_t dir = 1;
  for(int16_t oi = out, k = 0; oi >= 0; oi += dir, ++k) {
    const int16_t bound1 = (in - k < 0 ? 0 : in - k);
    const int16_t bound2 = (in + k > in_max - 1 ? in_max - 1 : in + k);
    for(int16_t ii = bound1; ii < bound2; ++ii) {
      if(maze[oi * cols + ii] == 2) return true;
    }
  }
  
  return false;
}

__device__ bool occurence_in_cone(uint16_t *const maze, const uint32_t rows, const uint32_t cols,
  const program_state state, const uint16_t val)
{
  switch(state.dir) {
    case east:  return occurence_in_cone_east (maze, rows, cols, state.row, state.col, val);
    case north: return occurence_in_cone_north(maze, rows, cols, state.row, state.col, val);
    case west:  return occurence_in_cone_west (maze, rows, cols, state.row, state.col, val);
    case south: return occurence_in_cone_south(maze, rows, cols, state.row, state.col, val);
  }
  
  // Should never be reached
  return false;
}

__device__ bool occurence_ahead(uint16_t *const maze, const uint32_t rows, const uint32_t cols,
  const program_state state, const uint16_t val)
{
  switch(state.dir) {
    case east:  return state.col + 1 < cols && maze[state.row * cols + state.col + 1] == val;
    case north: return state.row && maze[(state.row - 1) * cols + state.col] == val;
    case west:  return state.col && maze[state.row * cols + state.col - 1] == val;
    case south: return state.row + 1 < rows && maze[(state.row + 1) * cols + state.col] == val;
  }
  
  // Should never be reached
  return false;
}

#define child_loc(i, t) (&op_loc[(t) + 1 + op_loc[(i) + 1]])

__constant__ static const char *names[8] = {
  "hlt",
  "left",
  "right",
  "move",
  "if_wall_ahead",
  "if_goal_visible",
  "prog2",
  "debug_point"
};

__global__ void program_interpreter(uint16_t *const maze, const uint32_t rows, const uint32_t cols,
  uint32_t *offsets, uint32_t *programs, program_state state, uint32_t op_lim, program_state *res)
{
  const uint32_t our_index = blockIdx.x * blockDim.x + threadIdx.x;
  uint32_t *const our_program = programs + offsets[our_index];
  uint32_t *stack[255];
  uint8_t stack_head = 0;
  
  stack[0] = 0;
  while(op_lim) {
    uint32_t *const op_loc = stack[stack_head--];
    if(!op_loc) {
      stack[stack_head = 1] = our_program;
      continue;
    }
    const uint32_t op = *op_loc;
    // printf("%s\n", names[op]);
    
    switch(op) {
    // left
    case 1: --op_lim; state.dir = (cardinal_direction)((state.dir + 1) % 4); break;
      
    // right
    case 2: --op_lim; state.dir = (cardinal_direction)(state.dir == 0 ? 3 : state.dir - 1); break;
      
    // move
    case 3:
      --op_lim;
      if(occurence_ahead(maze, rows, cols, state, 1)) break;
      
      if(state.dir == north && state.row) --state.row;
      else if(state.dir == south && state.row + 1 < rows) ++state.row;
      else if(state.dir == west && state.col) --state.col;
      else if(state.dir == east && state.col + 1 < cols) ++state.col;
      break;
      
    // if_wall_ahead
    case 4:
      stack[++stack_head] = child_loc(occurence_ahead(maze, rows, cols, state, 1) ? 0 : 1, 2);
      break;
      
    // if_goal_visible
    case 5:
      stack[++stack_head] = child_loc(occurence_in_cone(maze, rows, cols, state, 2) ? 0 : 1, 2);
      break;
      
    // prog2
    case 6:
      stack[++stack_head] = child_loc(1, 2);
      stack[++stack_head] = child_loc(0, 2);
      break;
      
    case 7:
      --op_lim;
      printf("Reached debug point at %u\n", op_loc - our_program);
      break;
      
    default:
      printf("--- UNKNOWN INSTRUCTION %u ---\n", op);
      return;
    }
  }
  
  res[our_index] = state;
}


